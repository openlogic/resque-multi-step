require File.expand_path("../spec_helper", File.dirname(__FILE__))

$LOAD_PATH << File.dirname(__FILE__)
require 'acceptance_jobs'

$worker_pid = fork
if $worker_pid.nil?
  # in child
  exec "rake resque:work 'QUEUES=*' 'NAMESPACE=resque-multi-step-task-testing' INTERVAL=1 VERBOSE=1"
end

# wait for worker to come up
sleep 4
