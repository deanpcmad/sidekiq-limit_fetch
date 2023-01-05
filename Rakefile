# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

task :default do
  rspec = Rake::Task[:spec]
  rspec.invoke
  ENV['namespace'] = 'namespace'
  rspec.reenable
  rspec.invoke
end
