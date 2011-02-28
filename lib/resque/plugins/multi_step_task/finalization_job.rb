require 'resque/plugins/multi_step_task/constantization'

module Resque
  module Plugins
    class MultiStepTask
      # Executes a single finalization job 
      class FinalizationJob
        extend Constantization

        # Handle job invocation
        def self.perform(task_id, job_module_name, *args)
          task = MultiStepTask.find(task_id)
          
          begin
            constantize(job_module_name).perform(*args)
          rescue Exception
            task.increment_failed_count
            raise
          end
          
          task.increment_completed_count

          if fin_job_info = task.redis.lpop('finalize_jobs')
            # Queue the next finalization job
            Resque::Job.create(task.queue_name, FinalizationJob, task.task_id, 
                               *Yajl::Parser.parse(fin_job_info))
          else
            # There is nothing left to do so cleanup.
            task.nuke
          end

        end
      end
    end
  end
end

