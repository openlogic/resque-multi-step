# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/plugins/multi_step_task/version'

Gem::Specification.new do |spec|
  spec.name          = 'resque-multi-step'
  spec.version       = Resque::Plugins::MultiStepTask::VERSION
  spec.authors       = ['Peter Williams', 'Morgan Whitney', 'Jeff Gran', 'Cameron Mauch']
  spec.summary       = 'Provides multi-step tasks with finalization and progress tracking'
  spec.description   = 'Provides multi-step tasks with finalization and progress tracking'
  spec.homepage      = 'https://github.com/openlogic/resque-multi-step'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'redis-namespace'
  spec.add_dependency 'yajl-ruby'
  spec.add_dependency 'resque'
  spec.add_dependency 'resque-fairly'

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 2.13'
end
