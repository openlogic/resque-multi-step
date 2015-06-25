require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "resque-multi-step #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# Setup  for acceptance testing
require 'rubygems'
require 'resque/tasks'
require 'resque-fairly'

Resque.redis.namespace = ENV['NAMESPACE'] if ENV['NAMESPACE']

$LOAD_PATH << File.expand_path("lib", File.dirname(__FILE__))
require 'resque-multi-step'

$LOAD_PATH << File.expand_path("spec/acceptance", File.dirname(__FILE__))
require 'acceptance_jobs'

