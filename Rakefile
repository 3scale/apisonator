# encoding: utf-8

require '3scale/backend/configuration'
require '3scale/backend'
require '3scale/tasks/helpers'

include ThreeScale::Tasks::Helpers

load 'lib/3scale/tasks/connectivity.rake'

require '3scale/backend/logging/external'

ThreeScale::Backend::Logging::External.setup_rake

load 'lib/3scale/tasks/swagger.rake'

if Environment.testable?

  ENV['RACK_ENV'] = "test"
  require 'rake/testtask'

  task :default => [:test, :spec]

  test_task_dependencies = ['test:unit', 'test:integration']

  desc 'Run unit and integration tests'
  task :test => test_task_dependencies

  desc 'Benchmark'
  task :bench, [:file] do |_, args|
    require 'benchmark'
    require 'benchmark/ips'
    require 'pathname'
    require_relative 'test/test_helpers/configuration'
    require_relative 'test/test_helpers/fixtures'
    require_relative 'test/test_helpers/sequences.rb'

    filelist = if args[:file]
                 "#{args[:file].sub(/\Abench\//, '')}"
               else
                 '**/*_bench.rb'
               end
    FileList["#{File.dirname(__FILE__)}/bench/#{filelist}"].each do |f|
      bench = Pathname.new(f).cleanpath
      if bench.to_s.start_with?(File.dirname(__FILE__) + File::SEPARATOR)
        puts "Running benchmark #{bench}"
        Environment.using_async_redis? ? Sync { load(f) } : load(f)
      else
        STDERR.puts "Ignoring path #{f} as it points outside the project"
      end
    end

    puts "Benchmarks finished"
  end

  namespace :test do
    Rake::TestTask.new(:unit) do |task|
      task.test_files = FileList['test/unit/**/*_test.rb']
      task.verbose = true
      task.warning = false
    end

    Rake::TestTask.new(:integration) do |task|
      task.test_files = FileList['test/integration/**/*_test.rb']
      task.verbose = true
      task.warning = false
    end
  end

  require 'rspec/core/rake_task'
  spec_task_dependencies = [
    'spec:unit', 'spec:integration', 'spec:acceptance', 'spec:api', 'spec:use_cases', 'spec:server'
  ]

  desc 'Run RSpec tests'
  task :spec => spec_task_dependencies

  namespace :spec do

    require 'rspec/core/rake_task'
    desc 'Run all RSpec tests (unit, integration, acceptance, api, use_cases, server)'
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

    desc 'Run Rspec server tests'
    RSpec::Core::RakeTask.new(:server) do |task|
      task.pattern = 'spec/server/**/*_spec.rb'
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
    namespace :changelog do
      task :shortlog do
        version = `git describe --abbrev=0`.chomp
        STDOUT.puts "Changes from #{version} to HEAD\n\n"
        system "git shortlog --no-merges #{version}.."
      end

      # Link all issues and PRs in the changelog that have no link.
      #
      # By default links to PRs (althought GitHub redirects IIRC) but you can
      # specify an issue link by preceding it with "issue"/"Issue" or specify
      # a PR link (default) by preceding it with "PR".
      task :link_prs, [:file] do |_, args|
        file = args[:file] || File.join(File.dirname(__FILE__), 'CHANGELOG.md')

        File.open file, File::RDWR do |f|
          contents = f.read
          contents.
            # this regexp is not perfect but ok - ie. it would match issue(#5)
            gsub!(/(\b|[^[:alnum]])([iI]ssue|PR)?([\([:space:]])#(\d+)/) do

            # unfortunately gsub uses globals for groups :(
            type_prefix, type, separator, number = $1, $2, $3, $4

            link = case type.to_s.upcase
            when 'ISSUE'
              # even if quoted like this, remember that \ still escapes
              %{https://github.com/3scale/apisonator/issues/%s}
            else
              # default to PR links
              %{https://github.com/3scale/apisonator/pull/%s}
            end

            prefix = if type && separator == ' '
                       # remove "issue "
                       type_prefix
                     else
                       "#{type_prefix}#{separator}"
                     end

            prefix << "[##{number}](#{link % number})"
          end

          # Overwrite the changelog
          f.seek 0, IO::SEEK_SET
          f.write contents
        end
      end
    end

    task :tag do
      require File.dirname(__FILE__) + '/lib/3scale/backend/version'
      version = "v#{ThreeScale::Backend::VERSION}"
      STDOUT.puts "Creating tag #{version}"
      system "git tag -sa #{version} -m \"#{version}\""
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
        require 'license_finder'
        LicenseFinder::CLI::Main.start [
          'report',
          "--decisions-file=#{File.dirname(__FILE__)}/.dependency_decisions.yml",
          '--format=xml',
          '--quiet'
        ]
      end
    end
  end
end

desc 'Reschedule failed jobs'
task :reschedule_failed_jobs do
  reschedule_method = ThreeScale::Backend::FailedJobsScheduler.method(:reschedule_failed_jobs)

  result = if Environment.using_async_redis?
             Async { reschedule_method.call }.result
           else
             reschedule_method.call
           end

  puts "Rescheduled: #{result[:rescheduled]}. "\
       "Failed and discarded: #{result[:failed_while_rescheduling]}. "\
       "Pending failed jobs: #{result[:failed_current]}."
end

desc 'open debug console'
task :console do
  require 'irb'
  require '3scale/backend/job_fetcher'
  require_relative 'app/api/api.rb'

  # Good idea from IRB.start
  STDOUT.sync = true

  warn <<~EOF
    Examples:
    Sync { Resque.redis.queue_names }
    Sync { Resque.redis.peek_in_queue "priority" }
  EOF

  module ThreeScale
    module Backend
      extend Resque::Helpers

      if Environment.using_async_redis?
        Sync { binding.irb }
      else
        binding.irb
      end
    end
  end
end

namespace :stats do
  desc 'Delete stats of services marked for deletion'
  task :cleanup, [:redis_urls, :log_deleted_keys] do |_, args|
    redis_conns = redis_conns(args[:redis_urls])

    if redis_conns.empty?
      puts 'No Redis URLs specified'
      exit(false)
    end

    ThreeScale::Backend::Stats::Cleaner.delete!(
      redis_conns, log_deleted_keys: logger_for_deleted_keys(args[:log_deleted_keys])
    )
  end

  desc 'Delete stats keys set to 0'
  task :delete_stats_keys_set_to_0, [:redis_urls, :log_deleted_keys] do |_, args|
    redis_conns = redis_conns(args[:redis_urls])

    if redis_conns.empty?
      puts 'No Redis URLs specified'
      exit(false)
    end

    ThreeScale::Backend::Stats::Cleaner.delete_stats_keys_set_to_0(
      redis_conns, log_deleted_keys: logger_for_deleted_keys(args[:log_deleted_keys])
    )
  end
end

def redis_conns(urls)
  redis_urls = urls && urls.split(' ')

  return [] if redis_urls.nil? || redis_urls.empty?

  redis_urls.map do |redis_url|
    parsed_uri = URI.parse(ThreeScale::Backend::Storage::Helpers.send(
      :to_redis_uri, redis_url)
    )
    Redis.new(host: parsed_uri.host, port: parsed_uri.port)
  end
end

def logger_for_deleted_keys(arg_log_deleted_keys)
  arg_log_deleted_keys == 'true' ? STDOUT : nil
end
