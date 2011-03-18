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

desc 'Seed, put info into redis using data/postfile3, plan :default'
task :seed do
	system "ruby -Ilib bin/3scale_backend_seed -l -p data/postfile3"	
end

desc 'Seed, put info into redis using data/postfile3, plan :user'
task :seed_user do
	system "ruby -Ilib bin/3scale_backend_seed -u -l -p data/postfile3"	
end


desc 'Start the backend server in development'
task :start do
  system "ruby -Ilib bin/3scale_backend -p #{ENV['PORT'] || 3001} start"
end

desc 'Start a backend_worker in development'
task :start_worker do
  system "ruby -Ilib bin/3scale_backend_worker_no_daemon"
end

desc 'Stop a backend_worker in development'
task :stop_worker do
  system "ruby -Ilib bin/3scale_backend_worker stop"
end

desc 'Restart a backend_worker in development'
task :restart_worker do
  system "ruby -Ilib bin/3scale_backend_worker restart"
end




