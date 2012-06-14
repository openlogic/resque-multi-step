module MultiStepAcceptance
  class WaitJob
    def self.perform(duration)
      sleep duration
    end
  end
  
  class CounterJob
    def self.perform(key)
      Resque.redis.incr key
    end
  end
  
  class FailJob
    def self.perform
      raise "boom"
    end
  end

  class FailOnceJob
    def self.perform(key)
      if Resque.redis.exists(key)
        return
      else
        Resque.redis.set(key, 'was here')
        raise "boom"
      end
    end
  end

  class BackRefJob
    def self.perform
      str = multi_step_task_id
      mst = multi_step_task
    end
  end
  
end
