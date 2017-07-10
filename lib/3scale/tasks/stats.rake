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
      if ThreeScale::Backend::Stats::SendToKinesis.enabled?
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
      puts ThreeScale::Backend::Stats::SendToKinesis.enabled?
    end

    desc 'Enable sending to Kinesis'
    task :enable do
      puts ThreeScale::Backend::Stats::SendToKinesis.enable
    end

    desc 'Disable sending to Kinesis'
    task :disable do
      if ThreeScale::Backend::Stats::Storage.enabled?
        puts 'Error: disable bucket creation first. Otherwise, they will start accumulating.'
      else
        puts ThreeScale::Backend::Stats::SendToKinesis.disable
      end
    end

    desc 'Schedule one job to send all pending events to Kinesis'
    task :send do
      puts ThreeScale::Backend::Stats::SendToKinesis.schedule_job
    end

    # Pending events are the ones that were read but the buckets but have not
    # been sent to Kinesis for one of the following reasons:
    #   1) There was an error while sending them to Kinesis.
    #   2) There were not enough events to send a whole batch.
    desc 'Count number of pending events - were read from the buckets, but not sent'
    task :pending_events do
      puts ThreeScale::Backend::Stats::SendToKinesis.num_pending_events
    end

    desc 'Send pending events to Kinesis'
    task :flush, [:limit] do |_, args|
      limit = args.limit ? args.limit.to_i : nil
      puts ThreeScale::Backend::Stats::SendToKinesis.flush_pending_events(limit)
    end
  end

  namespace :redshift do
    desc 'Is Redshift importing enabled?'
    task :enabled? do
      puts ThreeScale::Backend::Stats::RedshiftImporter.enabled?
    end

    desc 'Enable Redshift importing'
    task :enable do
      puts ThreeScale::Backend::Stats::RedshiftImporter.enable
    end

    desc 'Disable Redshift importing'
    task :disable do
      puts ThreeScale::Backend::Stats::RedshiftImporter.disable
    end

    desc 'Import S3 events in Redshift'
    task :import do
      puts ThreeScale::Backend::Stats::RedshiftImporter.schedule_job
    end

    desc 'Show generation time (hour) of latest events imported in Redshift'
    task :latest do
      puts ThreeScale::Backend::Stats::RedshiftImporter.latest_imported_events_time
    end

    desc 'Is data consistent in the DB?'
    task :data_ok? do
      puts ThreeScale::Backend::Stats::RedshiftImporter.consistent_data?
    end
  end
end
