require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ResqueMultiStepTask" do
  it "defines MultiStepTask" do 
    defined?(Resque::Plugins::MultiStepTask).should be_true
  end
end
