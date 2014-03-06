module ThreeScale
  module Backend
    module Aggregator

      # Job for writing stats to mongo
      class StatsJob
        @queue = :stats

        def self.perform(bucket, enqueue_time)
          return unless Aggregator.mongo_enabled? && Aggregator.mongo_active?

          start_time = Time.now.getutc

          if bucket == "inf"
            buckets_to_save = Aggregator.get_old_buckets_to_process(bucket)
          else
            buckets_to_save = [bucket]
          end

          return if buckets_to_save.empty?

          buckets_to_save.each do |b|
            ## it will save all the changed keys from the oldest time bucket. If it
            ## fails it will put the bucket on the stats:failed so that it can be processed
            ## one by one via rake task
            Aggregator.save_to_mongo(b)
          end

          stats_mem = Memoizer.stats
          end_time  = Time.now.getutc
          Worker.logger.info("StatsJob #{bucket} #{buckets_to_save.size} #{(end_time-start_time).round(5)} #{(end_time.to_f-enqueue_time).round(5)} #{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")
        end
      end
    end
  end
end
