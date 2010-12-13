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

desc 'Tag and push the current version'
task :release => ['release:tag', 'release:push']

namespace :release do
  task :tag do
    require File.dirname(__FILE__) + '/lib/3scale/backend/version'
    system "git tag v#{ThreeScale::Backend::VERSION}"
  end

  task :push do
    system "git push --tags"
  end
end

desc 'Start the backend server in development'
task :start do
  system "ruby -Ilib bin/3scale_backend -p #{ENV['PORT'] || 3001} start"
end
