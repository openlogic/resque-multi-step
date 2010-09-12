module Resque
  module Plugins
    class MultiStepTask
      module AtomicCounters
        def counter(name)
          class_eval <<-INCR
            def increment_#{name}
              redis.incrby('#{name}', 1)
            end
            INCR

          class_eval <<-GETTER
            def #{name}
              redis.get('#{name}').to_i
            end
            GETTER
        end
      end
    end
  end
end
