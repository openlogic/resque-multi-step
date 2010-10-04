require File.expand_path("spec_helper", File.dirname(__FILE__))
require 'resque/plugins/multi_step_task'

# These tests are inherently sensitive to timing.  There are sleeps a
# the appropriate places to reduce/eliminate false failures where
# possible.  However, a failure does not always indicate a bug.  Run
# the test multiple times before accepting failures at face value.

describe "Acceptance: Successful task" do 
  let(:task) {
    Resque::Plugins::MultiStepTask.create("testing") do |task|
      task.add_job MultiStepAcceptance::CounterJob, "testing counter"
    end
  }

  before do 
    Resque.redis.del "testing counter"
    task
    sleep 1
  end

  it "processes its job" do 
    Resque.redis.get("testing counter").to_i.should == 1
  end

  it "removes queue when done" do 
    Resque.queues.should_not include(task.queue_name)
  end
end

describe "Acceptance: Successful tasks" do 
  let(:task) {
    Resque::Plugins::MultiStepTask.create("testing") do |task|
      task.add_job MultiStepAcceptance::WaitJob, 1
    end
  }

  before {task}

  it "create queue" do 
    Resque.queues.should include(task.queue_name)
  end

  it "queues jobs in its queue" do 
    Resque.peek(task.queue_name).should_not be_nil
  end

end

describe "Acceptance: Task with step failure" do 
  let(:task) {
    Resque::Plugins::MultiStepTask.create("testing") do |task|
      task.add_job MultiStepAcceptance::FailJob
    end
  }

  before do
    Resque::Failure.clear
    task
    sleep 1
  end

  it "put job in fail list" do 
    Resque::Failure.count.should == 1
  end

end

describe "Acceptance: Task with finalization failure" do 
  let(:task) {
    Resque.redis.del "testing counter"
    Resque::Plugins::MultiStepTask.create("testing") do |task|
      task.add_finalization_job MultiStepAcceptance::FailJob
    end
  }

  before do
    Resque::Failure.clear
    task
    sleep 1
  end
  
  it "put job in fail list" do 
    5.times {sleep 1 if Resque::Failure.count < 1}

    Resque::Failure.count.should == 1
  end
end

describe "Acceptance: Task with retried finalization failure" do 
  let(:task) {
    Resque.redis.del "testing counter"
    Resque::Plugins::MultiStepTask.create("testing") do |task|
      task.add_finalization_job MultiStepAcceptance::FailOnceJob, "fin-job"
      task.add_finalization_job MultiStepAcceptance::CounterJob,"testing counter"
    end
  }

  before do
    Resque::Failure.clear
    Resque.redis.del "testing counter"
    
    task
    sleep 1
    
    Resque::Failure.requeue 0
    sleep 1
  end

  it "completes task" do 
    lambda {
      Resque::Plugins::MultiStepTask.find(task.task_id)
    }.should raise_error(Resque::Plugins::MultiStepTask::NoSuchMultiStepTask)
  end


  it "runs following finalization jobs" do 
    Resque.redis.get("testing counter").to_i.should == 1
  end
  
end
