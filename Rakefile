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

  desc 'Seed, put info into redis using data/postfile3, plan :default'
  task :seed do
    system 'ruby -Ilib bin/3scale_backend_seed -l -p data/postfile3'
  end

  desc 'Seed, put info into redis using data/postfile3, plan :user'
  task :seed_user do
    system 'ruby -Ilib bin/3scale_backend_seed -u -l -p data/postfile3'
  end

  desc 'Start the backend server in development'
  task :start do
    system "ruby -Ilib bin/3scale_backend start -p #{ENV['PORT'] || 3001}"
  end

  desc 'Start a backend_worker in development'
  task :start_worker do
    system 'ruby -Ilib bin/3scale_backend_worker_no_daemon'
  end

  desc 'Stop a backend_worker in development'
  task :stop_worker do
    system 'ruby -Ilib bin/3scale_backend_worker stop'
  end

  desc 'Restart a backend_worker in development'
  task :restart_worker do
    system 'ruby -Ilib bin/3scale_backend_worker restart'
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
  namespace :buckets do
    desc 'Show number of pending buckets'
    task :size => :environment do
      puts ThreeScale::Backend::Stats::Info.pending_buckets_size
    end

    desc 'List pending buckets and their contents'
    task :list => :environment do
      puts ThreeScale::Backend::Stats::Info.pending_keys_by_bucket.inspect
    end

    desc 'Is bucket storage enabled?'
    task :enabled? => :environment do
      puts ThreeScale::Backend::Stats::Storage.enabled?
    end

    desc 'Enable bucket storage'
    task :enable => :environment do
      if ThreeScale::Backend::Stats::SendToKinesis.enabled?
        puts ThreeScale::Backend::Stats::Storage.enable!
      else
        puts 'Error: enable Kinesis first. Otherwise, buckets will start accumulating in Redis.'
      end
    end

    desc 'Disable bucket storage'
    task :disable! => :environment do
      puts ThreeScale::Backend::Stats::Storage.disable!
    end

    desc 'Delete all the pending buckets'
    task :delete! => :environment do
      puts ThreeScale::Backend::Stats::BucketStorage
               .new(ThreeScale::Backend::Storage.instance)
               .delete_all_buckets_and_keys
    end
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
      if ThreeScale::Backend::Stats::Storage.enabled?
        puts 'Error: disable bucket creation first. Otherwise, they will start accumulating.'
      else
        puts ThreeScale::Backend::Stats::SendToKinesis.disable
      end
    end

    desc 'Schedule one job to send all pending events to Kinesis'
    task :send => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.schedule_job
    end

    # Pending events are the ones that were read but the buckets but have not
    # been sent to Kinesis for one of the following reasons:
    #   1) There was an error while sending them to Kinesis.
    #   2) There were not enough events to send a whole batch.
    desc 'Count number of pending events - were read from the buckets, but not sent'
    task :pending_events => :environment do
      puts ThreeScale::Backend::Stats::SendToKinesis.num_pending_events
    end

    desc 'Send pending events to Kinesis'
    task :flush, [:limit] => :environment do |_, args|
      limit = args.limit ? args.limit.to_i : nil
      puts ThreeScale::Backend::Stats::SendToKinesis.flush_pending_events(limit)
    end
  end

  namespace :redshift do
    desc 'Is Redshift importing enabled?'
    task :enabled? => :environment do
      puts ThreeScale::Backend::Stats::RedshiftImporter.enabled?
    end

    desc 'Enable Redshift importing'
    task :enable => :environment do
      puts ThreeScale::Backend::Stats::RedshiftImporter.enable
    end

    desc 'Disable Redshift importing'
    task :disable => :environment do
      puts ThreeScale::Backend::Stats::RedshiftImporter.disable
    end

    desc 'Import S3 events in Redshift'
    task :import => :environment do
      puts ThreeScale::Backend::Stats::RedshiftImporter.schedule_job
    end
  end
end
