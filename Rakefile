# encoding: utf-8
require 'rake/testtask'

task :default => :test

desc 'Run all test (unit and integration)'
task :test => ['test:unit', 'test:integration']

namespace :test do
  Rake::TestTask.new(:unit) do |task|
    task.test_files = FileList['test/unit/**/*_test.rb']
    task.verbose = true
  end
  
  Rake::TestTask.new(:integration) do |task|
    task.test_files = FileList['test/integration/**/*_test.rb']
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

    gemspec.add_dependency 'aws-s3',           '~> 0.6'
    gemspec.add_dependency 'builder',          '~> 2.1'
    gemspec.add_dependency 'eventmachine',     '~> 0.12'
    gemspec.add_dependency 'em-redis',         '~> 0.2'
    gemspec.add_dependency 'hoptoad_notifier', '~> 2.2'
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
