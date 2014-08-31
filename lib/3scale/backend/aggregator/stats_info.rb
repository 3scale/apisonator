require_relative '../storage'
require_relative 'stats_keys'

module ThreeScale
  module Backend
    module Aggregator
      module StatsInfo

        extend StatsKeys

        module_function

        def pending_buckets
          storage.zrange(changed_keys_key, 0, -1)
        end

        def failed_buckets
          storage.smembers(failed_save_to_storage_stats_key)
        end

        def failed_buckets_at_least_once
          storage.smembers(failed_save_to_storage_stats_at_least_once_key)
        end

        def pending_buckets_size
          storage.zcard(changed_keys_key)
        end

        def pending_keys_by_bucket
          result = {}
          pending_buckets.each do |b|
            result[b] = storage.scard(changed_keys_bucket_key(b))
          end
          result
        end

        private

        def self.storage
          Storage.instance
        end
      end
    end
  end
end
