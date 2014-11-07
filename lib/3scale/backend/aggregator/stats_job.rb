require_relative '../storage_stats'
require_relative 'stats_info'

module ThreeScale
  module Backend
    module Aggregator

      class StatsJob < BackgroundJob
        @queue = :stats

        def self.perform_logged(bucket, enqueue_time)
          unless StorageStats.enabled? && StorageStats.active?
            @success_log_message = "#{bucket} StorageStats-not-active "
            return
          end

          buckets_to_save = if bucket == "inf"
            StatsInfo.get_old_buckets_to_process(bucket)
          else
            [bucket]
          end
          return if buckets_to_save.empty?

          buckets_to_save.each do |b|
            # It will save all the changed keys from the oldest time bucket. If
            # it fails it will put the bucket on the stats:failed so that it can
            # be processed one by one via rake task.
            StorageStats.save_changed_keys(b)
          end

          @success_log_message = "#{bucket} #{buckets_to_save.size} "
        end
      end
    end
  end
end
