module Resque
  module Plugins
    class MultiStepTask
      module Constantization
        # Courtesy ActiveSupport (Ruby on Rails) 
        def constantize(camel_cased_word)
          names = camel_cased_word.split('::')
          names.shift if names.empty? || names.first.empty?
          
          constant = Object
          names.each do |name|
            constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
          end
          constant
        end
      end
    end
  end
end

