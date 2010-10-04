$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'resque-multi-step'
require 'spec'
require 'spec/autorun'
require 'pp'

Spec::Runner.configure do |config|
  config.before do 
    # Tests are jailed to a testing namespace and that space does
    # contains in left over data from previous runs.
    Resque.redis.namespace = "resque-multi-step-task-testing"
    Resque.redis.keys('*').each{|k| Resque.redis.del k}

  end
end
