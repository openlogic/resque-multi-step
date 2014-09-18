require File.expand_path("../../../spec_helper", File.dirname(__FILE__))

module  Resque::Plugins
  class MultiStepTask
    describe FinalizationJob do 
      let(:task){MultiStepTask.create("some-task")}
      
      before do
        task.finalizable!
      end

      it "queues next finalization job when done" do 
        Resque::Job.should_receive(:create).with(anything, Resque::Plugins::MultiStepTask::FinalizationJob, task.task_id, 'TestJob', 42)
        
        task.add_finalization_job(TestJob, 42)

        FinalizationJob.perform(task.task_id, 'TestJob', 0)
      end

      it "cleans up on the last job" do 
        task.should_receive(:nuke)
        MultiStepTask.stub!(:find).and_return(task)
        
        FinalizationJob.perform(task.task_id, 'TestJob', 0)
      end
    end
    

    describe FinalizationJob, "performs job calling hooks" do

      let(:task) { MultiStepTask.create("some-task") }

      before do
        MultiStepTask.stub!(:find).and_return(task)
        TestJobWithHooks::DummyClass.should_receive :do_something
      end

      it "enqueues job with right parameters and executes after enqueue method" do
        args = {}
        FinalizationJob.perform(task.task_id, 'TestJobWithHooks', args)
        args[ 'before_perform' ].should eq "do_something"
      end
      
    end
  end
end

module ::TestJob
  def self.perform(*args)
    # no op
  end
end

module ::TestJobWithHooks

  class DummyClass;end

  def self.before_enqueue_do_something args
    args[ 'before_enqueue' ] = "do_something"
  end

  def self.after_enqueue_do_something args
    DummyClass.do_something
  end

  def self.before_perform_do_something args
    args[ 'before_perform' ] = "do_something"
  end

  def self.after_perform_do_something args
    DummyClass.do_something
  end

  def self.perform(*args)
    # no op
  end
end
