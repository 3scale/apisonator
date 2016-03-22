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
        KEYS_SLICE_CALL_TO_REDIS = 1000
        private_constant :KEYS_SLICE_CALL_TO_REDIS

        # If we have not read buckets for a long time, we might deal with lots
        # of keys in the union operation. This is why we define a constant that
        # limits the number of buckets that we send to the union op.
        #
        # Currently, we are running a Kinesis job every 2 min and the buckets
        # are being created every 10s. We could set the constant to 12
        # (120/10 = 12), but to be sure that we will call union just once on
        # each job, we are going to set it to 15.
        MAX_BUCKETS_REDIS_UNION = 15
        private_constant :MAX_BUCKETS_REDIS_UNION

        def initialize(storage)
          @storage = storage
        end

        # Deletes a bucket from the set, and also deletes its contents
        def delete_bucket(bucket)
          delete_bucket_content(bucket)
          storage.zrem(Keys.changed_keys_key, bucket)
        end

        # For each of the buckets in the range, deletes it from the set, and
        # also deletes its contents.
        def delete_range(last_bucket)
          buckets = storage.zrangebyscore(Keys.changed_keys_key, 0, last_bucket)
          buckets.each { |bucket| delete_bucket_content(bucket) }
          storage.zremrangebyscore(Keys.changed_keys_key, 0, last_bucket)
        end

        def delete_all_buckets_and_keys(options = {})
          Storage.disable!

          all_buckets.each do |bucket|
            keys = storage.smembers(Keys.changed_keys_bucket_key(bucket))
            unless options[:silent]
              puts "Deleting bucket: #{bucket}, containing #{keys.size} keys"
            end
            storage.del(Keys.changed_keys_bucket_key(bucket))
          end
          storage.del(Keys.changed_keys_key)
        end

        def all_buckets
          storage.zrange(Keys.changed_keys_key, 0, -1)
        end

        def buckets(first: '-inf', last: '+inf')
          storage.zrangebyscore(Keys.changed_keys_key, first, last)
        end

        def pending_buckets_size
          storage.zcard(Keys.changed_keys_key)
        end

        # Puts a key in a bucket. The bucket is created if it does not exist.
        # We could have decided to only fill the bucket if it existed, but that
        # would affect performance, because we would need to get all the
        # existing buckets to check if the given one exists in every call.
        def put_in_bucket(event_key, bucket)
          storage.zadd(Keys.changed_keys_key, bucket, bucket)
          storage.sadd(Keys.changed_keys_bucket_key(bucket), event_key)
        end

        def buckets_content_with_values(buckets)
          # Values are stored as strings in Redis, but we want integers.
          # There are some values that can be nil. This happens when the key
          # has a TTL and we read it once it has expired. Right now, event keys
          # with granularity = 'minute' expire after 180 s. We might need to
          # increase that to make sure that we do not miss any values.

          keys = unique_keys_in_buckets(buckets)
          values = keys.each_slice(KEYS_SLICE_CALL_TO_REDIS).flat_map do |keys_slice|
            storage.mget(keys_slice)
          end.map { |value| Integer(value) if value }

          Hash[keys.zip(values)]
        end

        private

        attr_reader :storage

        def unique_keys_in_buckets(buckets)
          buckets.each_slice(MAX_BUCKETS_REDIS_UNION).inject([]) do |res, buckets_slice|
            bucket_keys = buckets_slice.map { |bucket| Keys.changed_keys_bucket_key(bucket) }
            (res + storage.sunion(bucket_keys))
          end.uniq
        end

        def delete_bucket_content(bucket)
          storage.del(Keys.changed_keys_bucket_key(bucket))
        end
      end
    end
  end
end
