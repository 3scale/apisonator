module ThreeScale
  module Backend
    module Stats

      # This class manages the buckets where we are storing stats keys.
      # The way those buckets work is as follows: we are creating a bucket
      # every few seconds (10 by default now), and in each of those buckets,
      # we store all the stats keys that have changed in that bucket creation
      # interval.
      # The values of the keys that are stored in the buckets can be retrieved
      # with a normal call to redis.
      #
      # Currently, the Aggregator class is responsible for creating the
      # buckets, but we would like to change that in a future refactoring.
      class BucketStorage
        EVENTS_SLICE_CALL_TO_REDIS = 200
        private_constant :EVENTS_SLICE_CALL_TO_REDIS

        def initialize(storage)
          @storage = storage
        end

        def delete_bucket(bucket)
          storage.zrem(Keys.changed_keys_key, bucket)
        end

        def delete_range(last_bucket)
          storage.zremrangebyscore(Keys.changed_keys_key, 0, last_bucket)
        end

        def all_buckets
          storage.zrange(Keys.changed_keys_key, 0, -1)
        end

        # Puts a key in a bucket. The bucket is created if it does not exist.
        # We could have decided to only fill the bucket if it existed, but that
        # would affect performance, because we would need to get all the
        # existing buckets to check if the given one exists in every call.
        def put_in_bucket(event_key, bucket)
          storage.zadd(Keys.changed_keys_key, bucket, bucket)
          storage.sadd(Keys.changed_keys_bucket_key(bucket), event_key)
        end

        # This function returns a Hash with the keys that are present in the
        # bucket and their values
        def bucket_content_with_values(bucket)
          event_keys = bucket_content(bucket)
          event_keys_slices =  event_keys.each_slice(EVENTS_SLICE_CALL_TO_REDIS)

          # Values are stored as strings in Redis, but we want integers.
          # There are some values that can be nil. This happens when the key
          # has a TTL and we read it once it has expired. Right now, event keys
          # with granularity = 'minute' expire after 180 s. We might need to
          # increase that to make sure that we do not miss any values.
          event_values = event_keys_slices.flat_map do |event_keys_slice|
            storage.mget(event_keys_slice)
          end.map { |value| Integer(value) if value }

          Hash[event_keys.zip(event_values)]
        end

        private

        attr_reader :storage

        def bucket_content(bucket)
          storage.smembers(Keys.changed_keys_bucket_key(bucket))
        end
      end
    end
  end
end
