# encoding: utf-8

require 'airbrake/tasks'
require 'airbrake/rake_handler'

Airbrake.configure do |config|
  config.rescue_rake_exceptions = true
end

load 'lib/3scale/tasks/swagger.rake'
load 'lib/3scale/tasks/cubert.rake'

task :environment do
  require '3scale/backend'
  require '3scale/backend/stats/tasks'
end

def testable_environment?
  !%w(preview production).include?(ENV['RACK_ENV'])
end

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
    t.rspec_opts = ["--format RspecApiDocumentation::ApiFormatter"]
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
    system "ruby -Ilib bin/3scale_backend start -p #{ENV['PORT'] || 3001}"
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
end

desc 'Reschedule failed jobs'
task :reschedule_failed_jobs => :environment do
  count = Resque::Failure.count
  (Resque::Failure.count-1).downto(0).each { |i| Resque::Failure.requeue(i) }
  Resque::Failure.clear
  puts "resque:failed size: #{Resque::Failure.count} (from #{count})"
end

namespace :cache do
  desc 'Caching enabled?'
  task :caching_enabled? => :environment do
    puts ThreeScale::Backend::Transactor.caching_enabled?
  end

  desc 'Disable caching'
  task :disable_caching => :environment do
    puts ThreeScale::Backend::Transactor.caching_disable
  end

  desc 'Enable caching'
  task :enable_caching => :environment do
    puts ThreeScale::Backend::Transactor.caching_enable
  end
end

namespace :stats do
  namespace :panic_mode do
    desc '!!! Delete all time buckets and keys after disabling storage stats'
    task :delete_all_buckets_and_keys => :environment do
      puts ThreeScale::Backend::Stats::Tasks.delete_all_buckets_and_keys_only_as_rake!
    end

    desc 'Disable stats batch processing on storage stats. Stops saving to storage stats and to redis'
    task :disable_storage_stats => :environment do
      puts ThreeScale::Backend::Stats::Storage.disable!
    end

    desc 'Enable stats batch processing on storage stats'
    task :enable_storage_stats => :environment do
      puts ThreeScale::Backend::Stats::Storage.enable!
    end
  end

  desc 'Number of stats buckets active in Redis'
  task :buckets_size => :environment do
    puts ThreeScale::Backend::Stats::Info.pending_buckets_size
  end

  desc 'Number of keys in each stats bucket in Redis'
  task :buckets_info => :environment do
    puts ThreeScale::Backend::Stats::Info.pending_keys_by_bucket.inspect
  end

  desc 'Is storage stats batch processing enabled?'
  task :storage_stats_enabled? => :environment do
    puts ThreeScale::Backend::Stats::Storage.enabled?
  end

  namespace :kinesis do
    desc 'Is sending to Kinesis enabled?'
    task :enabled? => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.enabled?
    end

    desc 'Enable sending to Kinesis'
    task :enable => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.enable
    end

    desc 'Disable sending to Kinesis'
    task :disable => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.disable
    end

    desc 'Schedule one job to send all pending events to Kinesis'
    task :send_to_kinesis => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.schedule_job
    end

    # Pending events are the ones that were read but the buckets but have not
    # been sent to Kinesis for one of the following reasons:
    #   1) There was an error while sending them to Kinesis.
    #   2) There were not enough events to send a whole batch.
    desc 'Send pending events to Kinesis - events that were read from the buckets, but not sent'
    task :flush, [:limit] => :environment do |_, args|
      limit = args.limit ? args.limit.to_i : nil
      puts ThreeScale::Backend::Stats::SendToKinesis.flush_pending_events(limit)
    end
  end
end
