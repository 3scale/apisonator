require_relative 'storage'
require_relative 'info'

module ThreeScale
  module Backend
    module Stats
      class ReplicateJob < BackgroundJob
        @queue = :stats

        def self.perform_logged(bucket, enqueue_time)
          unless Storage.enabled? && Storage.active?
            @success_log_message = "#{bucket} StorageStats-not-active "
            return
          end

          if bucket == "inf"
            buckets_to_save = Info.get_old_buckets_to_process(bucket)
          else
            buckets_to_save = [bucket]
          end

          buckets_to_save.each do |b|
            # It will save all the changed keys from the oldest time bucket. If
            # it fails it will put the bucket on the stats:failed so that it can
            # be processed one by one via rake task.
            Storage.save_changed_keys(b)
          end

          @success_log_message = "#{bucket} #{buckets_to_save.size} "
        end
      end
    end
  end
end
