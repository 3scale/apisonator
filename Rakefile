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
