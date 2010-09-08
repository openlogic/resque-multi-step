require 'resque'
require 'redis-namespace'

module Resque
  module Plugins
    class MultiStepTask
      # Define an atomic counter attribute.
      def self.counter(name)
        class_eval <<INCR
          def increment_#{name}
            redis.incrby('#{name}', 1)
          end
INCR

          class_eval <<GETTER
            def #{name}
              redis.get('#{name}').to_i
            end
GETTER
      end

      NONCE_CHARS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

      # A bit of randomness to ensure tasks can be uniquely
      # identified.
      def self.nonce
        nonce = ""
        5.times{nonce << NONCE_CHARS[rand(NONCE_CHARS.length)]}
        nonce
      end
      
      # A redis client suitable for storing global mutli step task info.
      def self.redis
        @redis ||= Redis::Namespace.new("resque:multisteptask", :redis => Resque.redis)
      end

      # Does a task with the specified id exist?
      def self.active?(task_id)
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
      def self.create(slug=nil)
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

      # Find an existing MultiStepTask.
      #
      # @param [#to_s] task_id The unique key for the job group of interest.
      #
      # @return [ParallelJobGroup] The group of interest
      #
      # @raise [NoSuchMultiStepTask] If there is not a group with the specified key.
      def self.find(task_id)
        raise NoSuchMultiStepTask unless active?(task_id)

        pjg = new(task_id)
      end

      class << self
        private :new
      end

      # Instance methods 

      attr_reader :task_id

      # Initialize a newly instantiated parallel job group.
      #
      # @param [String] task_id The UUID of the group of interest.
      def initialize(task_id)
        @task_id = task_id
      end

      def redis
        @redis ||= Redis::Namespace.new("resque:multisteptask:#{task_id}", :redis => Resque.redis)
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
    end

    class NoSuchMultiStepTask < StandardError; end
  end
end
