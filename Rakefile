# encoding: utf-8
require 'rake/testtask'

task :default => :test

desc 'Run unit and integration tests'
task :test => ['test:unit', 'test:integration']

namespace :test do
  desc 'Run all tests (unit, integration and special)'
  task :all => ['test:unit', 'test:integration', 'test:special']

  Rake::TestTask.new(:unit) do |task|
    task.test_files = FileList['test/unit/**/*_test.rb']
    task.verbose = true
  end
  
  Rake::TestTask.new(:integration) do |task|
    task.test_files = FileList['test/integration/**/*_test.rb']
    task.verbose = true
  end

  Rake::TestTask.new(:special) do |task|
    task.test_files = FileList['test/special/**/*_test.rb']
    task.verbose = true
  end
end

begin
  require 'jeweler'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name     = '3scale_backend'
    gemspec.summary  = '3scale web service management system backend'
    gemspec.description = 'This gem provides a daemon that handles authorization and reporting of web services managed by 3scale.'

    gemspec.email    = 'adam@3scale.net'
    gemspec.homepage = 'http://www.3scale.net'
    gemspec.authors  = ['Adam Cigánek']

    gemspec.files.exclude 'data'
    gemspec.files.exclude 'deploy.rb'

    gemspec.executables = ['3scale_backend', '3scale_backend_worker']

    gemspec.add_dependency '3scale_core'
    gemspec.add_dependency 'aws-s3',                  '~> 0.6'
    gemspec.add_dependency 'builder',                 '~> 2.1'
    gemspec.add_dependency 'eventmachine',            '~> 0.12'
    gemspec.add_dependency 'redis',                   '~> 2.0'
    gemspec.add_dependency 'resque',                  '~> 1.9'
    gemspec.add_dependency 'hoptoad_notifier',        '~> 2.2'
    gemspec.add_dependency 'rack',                    '~> 1.1'
    gemspec.add_dependency 'rack-rest_api_versioning'
    gemspec.add_dependency 'thin',                    '~> 1.2'
    gemspec.add_dependency 'yajl-ruby',               '~> 0.7'
  end

  # HAX: I want only git:release, nothing else.
  Rake::Task['release'].clear_prerequisites
  task :release => 'git:release'

rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end


desc "Send all completed archives to a remote storage and clean them up."
task :archive => ['archive:store', 'archive:cleanup']

namespace :archive do
  task :store do
    require '3scale/backend'
    ThreeScale::Backend::Archiver.store(:tag => `hostname`.strip)
  end

  task :cleanup do
    require '3scale/backend'
    ThreeScale::Backend::Archiver.cleanup
  end
end
