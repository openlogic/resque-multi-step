$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'resque-multi-step-task'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  config.before(:each) do 
    Resque.redis.namespace = "resque-multi-step-task-testing"
    Resque.redis.keys('*').each{|k| Resque.redis.del k}
    
    # Tests are jailed to a testing namespace and that space does
    # contains in left over data from previous runs.
  end
end
