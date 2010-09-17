require File.expand_path("../../spec_helper", File.dirname(__FILE__))

module  Resque::Plugins
  describe MultiStepTask, "class" do 
    it "allows creating new tasks" do 
      MultiStepTask.create("brand-new-task").should be_kind_of(MultiStepTask)
    end

    it "allows creating new tasks with job specification block" do 
      MultiStepTask.create("brand-new-task") do |task|
        task.add_job(TestJob)
      end.should be_kind_of(MultiStepTask)
    end
    
    it "uniquifies task queues when creating new task with same slug as and existing one" do 
      a = MultiStepTask.create("some-task")
      b = MultiStepTask.create("some-task")
      
      a.queue_name.should_not == b.queue_name
    end 

    it "allows finding existing tasks" do 
      task_id = MultiStepTask.create("some-task").task_id
      
      MultiStepTask.find(task_id).should be_kind_of(MultiStepTask)
      MultiStepTask.find(task_id).task_id.should == task_id
    end

    it "raises exception on #find for non-existent task" do 
      lambda{
        MultiStepTask.find('nonexistent-task')
      }.should raise_error(MultiStepTask::NoSuchMultiStepTask)
    end

    it "allows mode to be set to :sync" do 
      MultiStepTask.mode = :sync
      MultiStepTask.should be_synchronous
    end

    it "allows mode to be set to :async" do 
      MultiStepTask.mode = :async
      MultiStepTask.should_not be_synchronous
    end
  end

  describe MultiStepTask do 
    let(:task) {MultiStepTask.create("some-task")}

    it "allows jobs to be added to task" do 
      lambda {
        task.add_job(TestJob)
      }.should_not raise_error
    end

    it "queues added job" do
      Resque::Job.should_receive(:create).with(task.queue_name, Resque::Plugins::MultiStepTask, task.task_id, 'TestJob')
      task.add_job(TestJob)
    end

    it "allows finalization jobs to be added" do 
      task.add_finalization_job(TestJob)
    end

    it "allows itself to become finalizable" do
      task.finalizable!
      task.should be_finalizable
    end

    it "queues assure finalization job when it becomes finalizable" do
      Resque::Job.should_receive(:create).with(task.queue_name, ::Resque::Plugins::MultiStepTask::AssureFinalization, task.task_id)
      task.finalizable!
    end

  end

  describe MultiStepTask, "synchronous mode" do 
    let(:task){MultiStepTask.create("some-task")}

    before do 
      MultiStepTask.mode = :sync
    end
    
    after do
      MultiStepTask.mode = :asyn
    end

    it "runs job when added" do
      TestJob.should_receive(:perform).with("my", "args")
      task.add_job(TestJob, "my", "args")
    end

    it "runs finalization job when added" do
      TestJob.should_receive(:perform).with("my", "args")
      task.add_finalization_job(TestJob, "my", "args")
      task.finalizable!
    end

    it "runs finalization jobs last" do
      TestJob.should_receive(:perform).with("my", "args").ordered
      MyFinalJob.should_receive(:perform).with("final", "args").ordered

      task.add_finalization_job(MyFinalJob, "final", "args")
      task.add_job(TestJob, "my", "args")
      task.finalizable!
    end
  end
  
  describe MultiStepTask, "finalization" do 
    let(:task){MultiStepTask.create("some-task")}

    before do
      task.finalizable!
    end

    it "invokes finalization jobs" do 
      TestJob.should_receive(:perform).with(42)

      task.add_finalization_job(TestJob, 42)
      task.finalize!
    end

    it "invokes finalization jobs in the order they are defined" do 
      TestJob.should_receive(:perform).with(42).ordered
      TestJob.should_receive(:perform).with(43).ordered
      TestJob.should_receive(:perform).with(44).ordered

      task.add_finalization_job(TestJob, 42)
      task.add_finalization_job(TestJob, 43)
      task.add_finalization_job(TestJob, 44)

      task.finalize!
    end

    it "runs finalization at end of last job" do 
      task.add_finalization_job(TestJob, 42)

      TestJob.should_receive(:perform).with(42)
      Resque::Job.reserve(task.queue_name).perform
    end

    it "removes queue from resque" do 
      task.add_job(TestJob)  # creates queue
      MultiStepTask.perform(task.task_id, 'TestJob')  # simulate runing final job

      Resque.queues.should_not include(task.task_id)
    end

    it "fails if finalization has already been run" do 
      task.finalize!
      lambda{task.finalize!}.should raise_error(::Resque::Plugins::MultiStepTask::FinalizationAlreadyBegun)
    end

    it "fails if task is not yet finalizable" do 
      task = MultiStepTask.create("some-task")
      lambda{task.finalize!}.should raise_error(::Resque::Plugins::MultiStepTask::NotReadyForFinalization)
    end

    it "fails if task has errors" do 
      TestJob.should_receive(:perform).and_raise('boo')
      task = MultiStepTask.create("some-task")
      MultiStepTask.perform(task.task_id, 'TestJob') rescue nil

      lambda{task.finalize!}.should raise_error(::Resque::Plugins::MultiStepTask::NotReadyForFinalization)
    end

  end

  describe MultiStepTask, "performing job" do 
    let(:task){MultiStepTask.create("some-task")}

    it "invokes specified job when #perform is called" do 
      TestJob.should_receive(:perform).with(42, 'aaa')

      MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa')
    end

    it "increments completed count on job success" do 
      lambda{
        MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa')
      }.should change(task, :completed_count).by(1)
    end
  end

  describe MultiStepTask, "performing job that fails" do 
    let(:task){MultiStepTask.create("some-task")}

    before do
      TestJob.should_receive(:perform).and_raise('boo')
    end

    it "increments failed count" do 
      lambda{
        MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa') rescue nil
      }.should change(task, :failed_count).by(1)
    end

    it "does not increment completed count" do 
      lambda{
        MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa') rescue nil
      }.should_not change(task, :completed_count).by(1)
    end

    it "bubbles raised exception job up to resque" do 
      lambda{
        MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa')
      }.should raise_exception("boo")
    end

    it "knows it is incomplete because of failures" do
      MultiStepTask.perform(task.task_id, 'TestJob', 42, 'aaa') rescue nil
      
      task.should be_incomplete_because_of_errors
    end
  end
end

module ::TestJob
  def self.perform(*args)
    # no op
  end
end

module ::MyFinalJob
  def self.perform(*args)
    # no op
  end
end

