# encoding: utf-8
require 'rake/testtask'

task :default => :test

desc 'Run unit and integration tests'
task :test => ['test:unit', 'test:integration']

task :environment do
  require '3scale/backend'
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

desc 'Reschedule failed jobs'
task :reschedule_failed_jobs => :environment do
  count = Resque::Failure.count
  (Resque::Failure.count-1).downto(0).each { |i| Resque::Failure.requeue(i) }
  Resque::Failure.clear
  Resque.redis.llen("queue:resque:queue:priority").times  { Resque.redis.rpoplpush("queue:resque:queue:priority","queue:priority") }
  Resque.redis.llen("queue:resque:queue:main").times { Resque.redis.rpoplpush("queue:resque:queue:main","queue:main")}
  puts "resque:failed size: #{Resque::Failure.count} (from #{count})"
end

namespace :cache do
  
  desc 'Statistic of the caching hit ratio'
  task :hit_ratio => :environment do 
    puts ThreeScale::Backend::Transactor.hit_ratio_stats().inspect
  end
  
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
    
    desc '!!! Delete all time buckets and keys after disabling cassandra'
    task :delete_all_buckets_and_keys => :environment do
      puts ThreeScale::Backend::Aggregator.delete_all_buckets_and_keys_only_as_rake!
    end
    
    desc 'Disable stats batch processing on cassandra. Stops saving to cassandra and to redis'  
    task :disable_cassandra => :environment do
        puts ThreeScale::Backend::Aggregator.disable_cassandra()
    end

    desc 'Enable stats batch processing on cassandra'  
    task :enable_cassandra => :environment do
        puts ThreeScale::Backend::Aggregator.enable_cassandra()
    end
    
    desc 'Schedule a StatsJob, will process all pending buckets including current (that should be done automatically)'
    task :insert_stats_job => :environment do
      puts ThreeScale::Backend::Aggregator.schedule_one_stats_job
    end
    
  end
  
  desc 'Number of stats buckets active in Redis'
  task :buckets_size => :environment do
    puts ThreeScale::Backend::Aggregator.pending_buckets_size()
  end
  
  desc 'Number of keys in each stats bucket in Redis'
  task :buckets_info => :environment do
    puts ThreeScale::Backend::Aggregator.pending_keys_by_bucket().inspect
  end

  desc 'Buckets currently failing to be processed'
  task :failed_buckets => :environment do
    puts ThreeScale::Backend::Aggregator.failed_buckets
  end  
  
  desc 'All buckets that failed to be processed at least once, even if ok now'
  task :failed_buckets_once => :environment do
    puts ThreeScale::Backend::Aggregator.failed_buckets_at_least_once
  end
     
  desc 'Activate saving to cassandra.'  
  task :activate_saving_to_cassandra => :environment do
      puts ThreeScale::Backend::Aggregator.activate_cassandra()
  end
  
  desc 'Deactivate saving to cassandra. Do only if cassandra is down or acting funny. Data is still saved in redis.'  
  task :deactivate_saving_to_cassandra => :environment do
      puts ThreeScale::Backend::Aggregator.deactivate_cassandra()
  end
  
  desc 'Are stats saving to cassandra or just piling in redis?'  
  task :cassandra_saving_active? => :environment do
      puts ThreeScale::Backend::Aggregator.cassandra_active?()
  end
  
  desc 'Is cassandra batch processing enabled?'  
  task :cassandra_enabled? => :environment do
      puts ThreeScale::Backend::Aggregator.cassandra_enabled?()
  end
  
  desc 'Process failed buckets (one by one)'
  task :process_failed => :environment do
    v = ThreeScale::Backend::Aggregator.failed_buckets
    if v.size==0
      puts "No failed buckets!"
    else
      puts "Saving bucket: #{v.first} ..."
      if !ThreeScale::Backend::Aggregator.time_bucket_already_inserted?(bucket)
        ThreeScale::Backend::Aggregator.save_to_cassandra(v.first)
        puts "Done"
      else
        puts "The time bucket was already inserted. Not saving it."
      end
    end
  end
  
  desc 'repeated batches on cassandra: if > 0, critical issue!! we would be over-counting'
  task :repeated_batches => :environment do
    v = ThreeScale::Backend::Aggregator.repeated_batches
    puts v.size
    if v.size>0
      puts v.inspect
    end
  end
  
  desc 'undo a repeated batch (needs the batch file that needs to be undone)'
  task :undo_repeated_batch => :environment do
    raise "No filename containing a CQL batch was passed as argument" if ARGV[1].nil?
    str = File.new(ARGV[1],"r").read
    raise "Filename #{ARGV[1]} is empty" if str.nil? || str.empty?
    ThreeScale::Backend::Aggregator.undo_repeated_batch(str)
  end

  desc 'check counter values for cassandra and redis, params: service_id, application_id, metric_id, time (optional)'
  task :check_counters => :environment do
    
    ##stats/{service:service_id}/cinstance:app_id/metric:metric_id/eternity
    service_id = ARGV[1]
    application_id = ARGV[2]
    metric_id = ARGV[3]
    timestamp = Time.parse_to_utc(ARGV[3]) if ARGV[4].nil?
    timestamp ||= Time.now.utc
    
    puts "Params: service_id: #{service_id}, application_id: #{application_id}, metric_id #{metric_id}, timestamp #{timestamp}"
    
    if service_id.nil? || application_id.nil? || metric_id.nil? || timestamp.nil?
      raise "Incorrect parameters: you must pass: service_id application_id metric_id timestamp (in full). For instance: service_id app_id metric_id \"2010-05-07 17:28:12'\"" 
    end
    
    results = ThreeScale::Backend::Aggregator.check_counters_only_as_rake(service_id, application_id, metric_id, timestamp)
    
    puts results.inspect
    exit
      
  end
  
  
  
end


