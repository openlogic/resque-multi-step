require File.expand_path("../spec_helper", File.dirname(__FILE__))

$LOAD_PATH << File.dirname(__FILE__)
require 'acceptance_jobs'

RSpec.configure do |c|
  c.before(:all) do
    puts '---------- Starting Resque Workers ----------'
    3.times do |index|
    system "BACKGROUND=yes PIDFILE=resque#{index}.pid QUEUE=* NAMESPACE=resque-multi-step-task-testing INTERVAL=0.5 rake resque:work"
    end
    sleep 3
  end

  c.after(:all) do
    sleep 1
    puts '---------- Stopping Resque Workers ----------'
    3.times do |index|
      pid = File.read("resque#{index}.pid").to_i
      File.delete("resque#{index}.pid")
      Process.kill('QUIT', pid)
    end
  end
end
