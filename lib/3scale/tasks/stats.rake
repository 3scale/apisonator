namespace :stats do
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
      puts ThreeScale::Backend::Stats::Storage.enabled?
    end

    desc 'Enable bucket storage'
    task :enable do
      if ThreeScale::Backend::Analytics::Kinesis::Exporter.enabled?
        puts ThreeScale::Backend::Stats::Storage.enable!
      else
        puts 'Error: enable Kinesis first. Otherwise, buckets will start accumulating in Redis.'
      end
    end

    desc 'Disable bucket storage'
    task :disable! do
      puts ThreeScale::Backend::Stats::Storage.disable!
    end

    desc 'Delete all the pending buckets'
    task :delete! do
      puts bucket_storage.delete_all_buckets_and_keys
    end

    desc 'Was the latest disable automatic to avoid filling Redis?'
    task :emergency? do
      puts ThreeScale::Backend::Stats::Storage.last_disable_was_emergency?
    end

    def bucket_storage
      ThreeScale::Backend::Stats::Storage.bucket_storage
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
      if ThreeScale::Backend::Stats::Storage.enabled?
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

    def kinesis_exporter
      ThreeScale::Backend::Analytics::Kinesis::Exporter
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

    def redshift_importer
      ThreeScale::Backend::Analytics::Redshift::Importer
    end
  end
end
