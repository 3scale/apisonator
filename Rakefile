# encoding: utf-8

require '3scale/backend'

def testable_environment?
  !%w(preview production).include?(ENV['RACK_ENV'])
end

def saas?
  ThreeScale::Backend.configuration.saas
end

if saas?
  require 'airbrake/tasks'
  require 'airbrake/rake_handler'

  Airbrake.configure do |config|
    config.rescue_rake_exceptions = true
  end

  load 'lib/3scale/tasks/swagger.rake'
  load 'lib/3scale/tasks/stats.rake'

  if testable_environment?
    require 'rake/testtask'

    task :default => [:test, :spec]

    test_task_dependencies = ['test:unit', 'test:integration']

    desc 'Run unit and integration tests'
    task :test => test_task_dependencies

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

    require 'rspec/core/rake_task'
    desc 'Run specs'
    RSpec::Core::RakeTask.new

    desc 'Generate API request documentation from API specs'
    RSpec::Core::RakeTask.new('docs:generate') do |t|
      t.pattern = 'spec/acceptance/**/*_spec.rb'
      t.rspec_opts = ['--format RspecApiDocumentation::ApiFormatter']
    end

    desc 'Tag and push the current version'
    task :release => ['release:tag', 'release:push']

    namespace :release do
      task :tag do
        require File.dirname(__FILE__) + '/lib/3scale/backend/version'
        system "git tag v#{ThreeScale::Backend::VERSION}"
      end

      task :push do
        system 'git push --tags'
      end
    end

    desc 'Start the backend server in development'
    task :start do
      system "ruby -Ilib bin/3scale_backend start -p #{ENV['PORT'] || 3001}"
    end

    desc 'Start a backend_worker in development'
    task :start_worker do
      system 'ruby -Ilib bin/3scale_backend_worker --no-daemonize'
    end

    desc 'Stop a backend_worker in development'
    task :stop_worker do
      system 'ruby -Ilib bin/3scale_backend_worker stop'
    end

    desc 'Restart a backend_worker in development'
    task :restart_worker do
      system 'ruby -Ilib bin/3scale_backend_worker restart'
    end

    desc 'Check license compliance of dependencies'
    task :license_finder do
      STDOUT.puts "Checking license compliance\n"
      unless system("license_finder --decisions-file=#{File.dirname(__FILE__)}" \
                    "/.dependency_decisions.yml")
        STDERR.puts "\n*** License compliance test failed  ***\n"
        exit 1
      end
    end
  end
end

desc 'Reschedule failed jobs'
task :reschedule_failed_jobs do
  result = ThreeScale::Backend::FailedJobsScheduler.reschedule_failed_jobs
  puts "Rescheduled: #{result[:rescheduled]}. "\
       "Failed and discarded: #{result[:failed_while_rescheduling]}. "\
       "Pending failed jobs: #{result[:failed_current]}."
end
