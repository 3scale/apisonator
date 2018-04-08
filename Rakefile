# encoding: utf-8

require '3scale/backend/configuration'
require '3scale/backend'

def testable_environment?
  !%w(preview production).include?(ENV['RACK_ENV'])
end

def saas?
  ThreeScale::Backend.configuration.saas
end

if saas?
  require '3scale/backend/logging/external'

  ThreeScale::Backend::Logging::External.setup_rake

  load 'lib/3scale/tasks/swagger.rake'
  load 'lib/3scale/tasks/stats.rake'

  if testable_environment?
    require 'rake/testtask'

    task :default => [:test, :spec]

    test_task_dependencies = ['test:unit', 'test:integration']

    desc 'Run unit and integration tests'
    task :test => test_task_dependencies

    desc 'Benchmark'
    task :bench do
      require 'benchmark/ips'
      require 'pathname'
      require File.dirname(__FILE__) + '/test/test_helpers/configuration'

      FileList['bench/**/*_bench.rb'].each do |f|
        bench = Pathname.new(f).relative_path_from(Pathname.new('./bench'))
        puts "Running benchmark #{bench}"
        load f
      end

      puts "Benchmarks finished"
    end

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
    spec_task_dependencies = ['spec:unit', 'spec:integration', 'spec:acceptance', 'spec:api', 'spec:use_cases']

    desc 'Run RSpec tests'
    task :spec => spec_task_dependencies

    namespace :spec do

      require 'rspec/core/rake_task'
      desc 'Run all RSpec tests (unit, integration, acceptance, api, use_cases)'
      task :all => spec_task_dependencies

      desc 'Run RSpec unit tests'
      RSpec::Core::RakeTask.new(:unit) do |task|
        task.pattern = 'spec/unit/**/*_spec.rb'
        #We require spec_helper because some tests
        #do not include spec_helper by themselves
        task.rspec_opts = '--require=spec_helper'
      end

      desc 'Run RSpec integration tests'
      RSpec::Core::RakeTask.new(:integration) do |task|
        task.pattern = 'spec/integration/**/*_spec.rb'
        task.rspec_opts = '--require=spec_helper'
      end

      desc 'Run RSpec acceptance tests'
      RSpec::Core::RakeTask.new(:acceptance) do |task|
        task.pattern = 'spec/acceptance/**/*_spec.rb'
        task.rspec_opts = '--require=spec_helper'
      end

      desc 'Run RSpec api tests'
      RSpec::Core::RakeTask.new(:api) do |task|
        task.pattern = 'spec/api/**/*_spec.rb'
        task.rspec_opts = '--require=spec_helper'
      end

      desc 'Run RSpec use_cases tests'
      RSpec::Core::RakeTask.new(:use_cases) do |task|
        task.pattern = 'spec/use_cases/**/*_spec.rb'
        task.rspec_opts = '--require=spec_helper'
      end

      desc 'Run RSpec test/s specified by input file pattern'
      RSpec::Core::RakeTask.new(:specific, :test_name) do |task, task_args|
        task.pattern = "#{task_args[:test_name]}"
        task.rspec_opts = '--require=spec_helper'
      end

    end

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

    namespace :license_finder do
      namespace :report do
        desc 'Generate an XML report for licenses'
        task :xml do
          # This is a hack to monkey patch license_finder that produces warnings :(
          prev_verbose_lvl = $VERBOSE
          $VERBOSE = nil
          require 'license_finder_xml_reporter/cli/main'
          $VERBOSE = prev_verbose_lvl
          LicenseFinder::CLI::Main.start [
            'report',
            "--decisions-file=#{File.dirname(__FILE__)}/.dependency-decisions.yml",
            '--format=xml'
          ]
        end
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
