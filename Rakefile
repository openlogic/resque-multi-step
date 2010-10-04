require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "resque-multi-step"
    gem.summary = "Provides multi-step tasks with finalization and progress tracking"
    gem.description = "Provides multi-step tasks with finalization and progress tracking"
    gem.email = "pezra@barelyenough.org"
    gem.homepage = "http://github.com/pezra/resque-multi-step"
    gem.authors = ["Peter Williams", "Morgan Whitney"]

    gem.add_development_dependency "rspec", ">= 1.2.9"

    gem.add_dependency 'redis-namespace', '~> 0.8.0'
    gem.add_dependency 'resque', '~> 1.10'
    gem.add_dependency 'resque-fairly', '~> 1.0'

    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

namespace(:spec) do 
  Spec::Rake::SpecTask.new(:acceptance) do |spec|
    spec.libs << 'lib' << 'spec'
    spec.spec_files = FileList['spec/acceptance/*_spec.rb']
  end
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
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

