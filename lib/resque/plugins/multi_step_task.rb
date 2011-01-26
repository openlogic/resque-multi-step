require 'resque'
require 'redis-namespace'
require 'resque/plugins/multi_step_task/assure_finalization'
require 'resque/plugins/multi_step_task/finalization_job'
require 'resque/plugins/multi_step_task/constantization'
require 'resque/plugins/multi_step_task/atomic_counters'

module Resque
  module Plugins
    class MultiStepTask
      class NoSuchMultiStepTask < StandardError; end
      class NotReadyForFinalization < StandardError; end
      class FinalizationAlreadyBegun < StandardError; end

      class << self
        include Constantization
        
        NONCE_CHARS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

        # A bit of randomness to ensure tasks are uniquely identified.
        def nonce
          nonce = ""
          5.times{nonce << NONCE_CHARS[rand(NONCE_CHARS.length)]}
          nonce
        end
        
        # A redis client suitable for storing global mutli-step task info.
        def redis
          @redis ||= Redis::Namespace.new("resque:multisteptask", :redis => Resque.redis)
        end

        # Does a task with the specified id exist?
        def active?(task_id)
          redis.sismember("active-tasks", task_id)
        end
        
        # Create a brand new parallel job group.
        #
        # @param [#to_s] slug The descriptive slug of the new job.  Default: a
        #   random UUID
        #
        # @yield [multi_step_task] A block to define the work to take place in parallel
        #
        # @yieldparam [MultiStepTask] The newly create job group.
        #
        # @return [MultiStepTask] The new job group
        def create(slug=nil)
          task_id = if slug.nil? || slug.empty?
                      "multi-step-task" 
                    else
                      slug.to_s
                    end
          task_id << "~" << nonce
          
          pjg = new(task_id)
          pjg.nuke
          redis.sadd("active-tasks", task_id)
          redis.sismember("active-tasks", task_id)
          if block_given?
            yield pjg
            pjg.finalizable!
          end
          
          pjg
        end

        # Prevent calling MultiStepTask.new
        private :new
        
        # Find an existing MultiStepTask.
        #
        # @param [#to_s] task_id The unique key for the job group of interest.
        #
        # @return [ParallelJobGroup] The group of interest
        #
        # @raise [NoSuchMultiStepTask] If there is not a group with the specified key.
        def find(task_id)
          raise NoSuchMultiStepTask unless active?(task_id)
          
          pjg = new(task_id)
        end

        # Handle job invocation
        def perform(task_id, job_module_name, *args)
          task = perform_without_maybe_finalize(task_id, job_module_name, *args)
          task.maybe_finalize
        end

        def perform_without_maybe_finalize(task_id, job_module_name, *args)
          task = MultiStepTask.find(task_id)
          begin
            constantize(job_module_name).perform(*args)
          rescue Exception => e
            task.increment_failed_count
            raise
          end
          task.increment_completed_count
          task
        end

        def perform_finalization(task_id, job_module_name, *args)
          perform_without_maybe_finalize(task_id, job_module_name, *args)
        end

        # Normally jobs that are part of a multi-step task are run
        # asynchronously by putting them on a queue.  However, it is
        # often more convenient to just run the jobs synchronously as
        # they are registered in a development environment.  Setting
        # mode to `:sync` provides a way to do just that.
        #
        # @param [:sync,:async] sync_or_async
        def mode=(sync_or_async)
          @@synchronous = (sync_or_async == :sync)
        end

        def synchronous?
          @@synchronous
        end
        @@synchronous = false
      end

      def synchronous?
        @@synchronous
      end

      # Instance methods 

      include Constantization

      attr_reader :task_id

      extend AtomicCounters

      counter :normal_job_count
      counter :finalize_job_count

      counter :completed_count
      counter :failed_count


      # Initialize a newly instantiated parallel job group.
      #
      # @param [String] task_id The UUID of the group of interest.
      def initialize(task_id)
        @task_id = task_id
      end

      def redis
        @redis ||= Redis::Namespace.new("resque:multisteptask:#{task_id}", :redis => Resque.redis)
      end

      # The total number of jobs that are part of this task.
      def total_job_count
        normal_job_count + finalize_job_count
      end

      # Removes all data from redis related to this task.
      def nuke
        redis.keys('*').each{|k| redis.del k}
        Resque.remove_queue queue_name
        self.class.redis.srem('active-tasks', task_id)
      end
      
      # The name of the queue for jobs what are part of this task.
      def queue_name
        task_id
      end

      # Add a job to this task
      #
      # @param [Class,Module] job_type The type of the job to be performed.
      def add_job(job_type, *args)
        increment_normal_job_count

        if synchronous?
          self.class.perform(task_id, job_type.to_s, *args)
        else
          Resque::Job.create(queue_name, self.class, task_id, job_type.to_s, *args)
        end
      end

      # Finalization jobs are performed after all the normal jobs
      # (i.e. the ones registered with #add_job) have been completed.
      # Finalization jobs are performed in the order they are defined.
      #
      # @param [Class,Module] job_type The type of job to be performed.
      def add_finalization_job(job_type, *args)
        increment_finalize_job_count

        redis.rpush 'finalize_jobs', Yajl::Encoder.encode([job_type.to_s, *args])
      end

      # A multi-step task is finalizable when all the normal jobs (see
      # #add_job) have been registered.  Finalization jobs will not be
      # executed until the task becomes finalizable regardless of the
      # number of jobs that have been completed.
      def finalizable?
        redis.exists 'is_finalizable'
      end

      # Make this multi-step task finalizable (see #finalizable?).
      def finalizable!
        redis.set 'is_finalizable', true
        if synchronous?
          maybe_finalize
        else
          Resque::Job.create(queue_name, AssureFinalization, self.task_id)
        end
      end

      # Finalize this job group.  Finalization entails running all
      # finalization jobs serially in the order they were defined.
      #
      # @raise [NotReadyForFinalization] When called before all normal
      #   jobs have been attempted.
      #
      # @raise [FinalizationAlreadyBegun] If some other process has
      #   already started (and/or finished) the finalization process.
      def finalize!
        raise FinalizationAlreadyBegun unless MultiStepTask.active?(task_id)
        raise NotReadyForFinalization if !ready_for_finalization? || incomplete_because_of_errors?

        # Only one process is allowed to start the finalization
        # process.  This setnx acts a global mutex for other processes
        # that finish about the same time.
        raise FinalizationAlreadyBegun unless redis.setnx("i_am_the_finalizer", 1)
        
        if synchronous?
          sync_finalize!
        else
          if fin_job_info = redis.lpop('finalize_jobs')
            fin_job_info = Yajl::Parser.parse(fin_job_info)
            Resque::Job.create(queue_name, FinalizationJob, self.task_id, *fin_job_info)
          else
            # There is nothing left to do so cleanup.
            nuke
          end
        end
      end

      def sync_finalize!
        while fin_job_info = redis.lpop('finalize_jobs')
          job_class_name, *args = Yajl::Parser.parse(fin_job_info)
          self.class.perform_finalization(task_id, job_class_name, *args)
        end
        nuke
      end

      # Execute finalization sequence if it is time.
      def maybe_finalize
        return unless ready_for_finalization? && !incomplete_because_of_errors?
        finalize!
      end

      # Is this task at the point where finalization can occur.
      def ready_for_finalization?
        finalizable? && completed_count >= normal_job_count
      end

      # If a normal or finalization job fails (i.e. raises an
      # exception) the task as a whole is considered to be incomplete.
      # The finalization sequence will not be performed.  If the
      # failure occurred during finalization any remaining
      # finalization job will not be run.
      #
      # If the failed job is retried and succeeds finalization will
      # proceed at usual.
      def incomplete_because_of_errors?
        failed_count > 0 && completed_count < normal_job_count
      end
      
      def unfinalized_because_of_errors?
        failed_count > 0 && completed_count < (normal_job_count + finalize_job_count)
      end

    end
  end
end

