namespace :stats do
  def bucket_storage
    ThreeScale::Backend::Stats::Storage.bucket_storage
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
end
