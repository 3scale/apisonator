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

        ## returns the array of buckets to process that are < bucket
        def get_old_buckets_to_process(bucket = "inf", redis_conn = nil)

          ## there should be very few elements on the changed_keys_key

          redis_conn = storage if redis_conn.nil?
          score_bucket_key = bucket.split(":").last

          redis_conn.eval(
            buckets_to_process_script,
            keys: [changed_keys_key],
            argv: ["(#{score_bucket_key}"]
          )
        end

        private

        def self.storage
          Storage.instance
        end

        def self.buckets_to_process_script
          <<EOF
  local keys = redis.call('zrevrange', KEYS[1], 0, -1)
  local num_keys_rem = redis.call('zremrangebyscore', KEYS[1], "-inf", ARGV[1])

  local keys_to_process = {}
  if num_keys_rem >= 1 then
    for i=1,num_keys_rem do
      local reverse_index = #keys - (i-1)
      table.insert(keys_to_process, keys[reverse_index])
    end
  end

  return keys_to_process
EOF
        end
      end
    end
  end
end
