require File.expand_path("../../spec_helper", File.dirname(__FILE__))

module  Resque::Plugins
  describe MultiStepTask, "class" do 
    it "allows creating new tasks" do 
      MultiStepTask.create("brand-new-task").should be_kind_of(MultiStepTask)
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
      }.should raise_error(NoSuchMultiStepTask)
    end

  end
end
