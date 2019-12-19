namespace :stats do
  def bucket_storage
    ThreeScale::Backend::Stats::Storage.bucket_storage
  end

  def kinesis_exporter
    ThreeScale::Backend::Analytics::Kinesis::Exporter
  end

  def redshift_importer
    ThreeScale::Backend::Analytics::Redshift::Importer
  end

  def stats_storage
    ThreeScale::Backend::Stats::Storage
  end

  namespace :buckets do
    desc 'Show number of pending buckets'
    task :size do
      puts bucket_storage.pending_buckets_size
    end

    desc 'List pending buckets and their contents'
    task :list do
      puts bucket_storage.pending_keys_by_bucket.inspect
    end

    desc 'Is bucket storage enabled?'
    task :enabled? do
      stats_storage.enabled?
    end

    desc 'Enable bucket storage'
    task :enable do
      if kinesis_exporter.enabled?
        puts stats_storage.enable!
      else
        puts 'Error: enable Kinesis first. Otherwise, buckets will start accumulating in Redis.'
      end
    end

    desc 'Disable bucket storage'
    task :disable! do
      puts stats_storage.disable!
    end

    desc 'Delete all the pending buckets'
    task :delete! do
      puts bucket_storage.delete_all_buckets_and_keys
    end

    desc 'Was the latest disable automatic to avoid filling Redis?'
    task :emergency? do
      puts stats_storage.last_disable_was_emergency?
    end
  end

  namespace :kinesis do
    desc 'Is sending to Kinesis enabled?'
    task :enabled? do
      puts kinesis_exporter.enabled?
    end

    desc 'Enable sending to Kinesis'
    task :enable do
      puts kinesis_exporter.enable
    end

    desc 'Disable sending to Kinesis'
    task :disable do
      if stats_storage.enabled?
        puts 'Error: disable bucket creation first. Otherwise, they will start accumulating.'
      else
        puts kinesis_exporter.disable
      end
    end

    desc 'Schedule one job to send all pending events to Kinesis'
    task :send do
      puts kinesis_exporter.schedule_job
    end

    # Pending events are the ones that were read but the buckets but have not
    # been sent to Kinesis for one of the following reasons:
    #   1) There was an error while sending them to Kinesis.
    #   2) There were not enough events to send a whole batch.
    desc 'Count number of pending events - were read from the buckets, but not sent'
    task :pending_events do
      puts kinesis_exporter.num_pending_events
    end

    desc 'Send pending events to Kinesis'
    task :flush, [:limit] do |_, args|
      limit = args.limit ? args.limit.to_i : nil
      puts kinesis_exporter.flush_pending_events(limit)
    end
  end

  namespace :redshift do
    desc 'Is Redshift importing enabled?'
    task :enabled? do
      puts redshift_importer.enabled?
    end

    desc 'Enable Redshift importing'
    task :enable do
      puts redshift_importer.enable
    end

    desc 'Disable Redshift importing'
    task :disable do
      puts redshift_importer.disable
    end

    desc 'Import S3 events in Redshift'
    task :import do
      puts redshift_importer.schedule_job
    end

    desc 'Show generation time (hour) of latest events imported in Redshift'
    task :latest do
      puts redshift_importer.latest_imported_events_time
    end

    desc 'Is data consistent in the DB?'
    task :data_ok? do
      puts redshift_importer.consistent_data?
    end
  end

  desc 'Delete stats of services marked for deletion'
  task :cleanup, [:redis_urls, :log_deleted_keys] do |_, args|
    redis_urls = args[:redis_urls] && args[:redis_urls].split(' ')

    if redis_urls.nil? || redis_urls.empty?
      puts 'No Redis URLs specified'
      exit(false)
    end

    redis_clients = redis_urls.map do |redis_url|
      parsed_uri = URI.parse(ThreeScale::Backend::Storage::Helpers.send(
        :to_redis_uri, redis_url)
      )
      Redis.new(host: parsed_uri.host, port: parsed_uri.port)
    end

    log_deleted = args[:log_deleted_keys] == 'true' ? STDOUT : nil

    ThreeScale::Backend::Stats::Cleaner.delete!(
      redis_clients, log_deleted_keys: log_deleted
    )
  end
end
