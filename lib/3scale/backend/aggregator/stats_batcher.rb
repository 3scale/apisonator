module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher

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

        # TODO: Remove this method after remove mongo dependency.
        def check_counters_only_as_rake(service_id, application_id, metric_id, timestamp)
          granularities = [:eternity, :month, :day, :hour, :minute]
          results = { redis: {}, mongo: {} }

          service_prefix     = service_key_prefix(service_id)
          application_prefix = application_key_prefix(service_prefix, application_id)
          application_metric_prefix = metric_key_prefix(application_prefix, metric_id)

          mongo_conditions = {
            s: service_id,
            a: application_id,
            m: metric_id,
          }

          granularities.each do |gra|
            redis_key = counter_key(application_metric_prefix, gra, timestamp)
            results[:redis][gra] = storage.get(redis_key)
            results[:mongo][gra] = storage_mongo.get(gra, timestamp, mongo_conditions)
          end

          results
        end

        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          StorageStats.disable!

          (failed_buckets + pending_buckets).each do |bucket|
            keys = storage.smembers(changed_keys_bucket_key(bucket))
            unless options[:silent] == true
              puts "Deleting bucket: #{bucket}, containing #{keys.size} keys"
            end
            storage.del(changed_keys_bucket_key(bucket))
          end
          storage.del(changed_keys_key);
          storage.del(failed_save_to_storage_stats_key)
          storage.del(failed_save_to_storage_stats_at_least_once_key)
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

        def save_to_mongo(bucket)
          ## FIXME: this has to go aways, just temporally to check for concurrency issues
          storage.pipelined do
            storage.lpush("temp_list","#{bucket}-#{Time.now.utc}-#{Thread.current.object_id}")
            storage.ltrim("temp_list",0,1000-1)
          end

          begin
            keys_that_changed = storage.smembers(changed_keys_bucket_key(bucket))

            return if keys_that_changed.nil? || keys_that_changed.empty?

            # i think that we don't need to storage the rest of keys
            # (eternity,week, month) because we will not send them to mongo.
#            keys_that_changed = keys_that_changed.select { |k| k =~ /day|hour|minute/ }

            keys_that_changed = keys_that_changed.reject { |k| k =~ /week/ }
            values = storage.mget(*keys_that_changed)

            keys_that_changed.each_with_index do |key, i|
              storage_mongo.prepare_batch(key, values[i].to_i)
            end

            storage_mongo.execute_batch

            ## now we have to clean up the data in redis that has been processed
            storage.pipelined do
              storage.del(changed_keys_bucket_key(bucket))
              storage.srem(failed_save_to_storage_stats_key, bucket)
            end
          rescue Exception => e
            ## could not write to mongo, reschedule

            begin
              Airbrake.notify(e, parameters: { bucket: bucket })
            rescue Exception => no_airbrake
              ## this is a bit hackish... this will only happens when save_to_mongo blows when
              ## called from a rake task (rake stats:process_failed)
              puts "Error: #{e.inspect}"
            end
            storage.sadd(failed_save_to_storage_stats_at_least_once_key, bucket)
            storage.sadd(failed_save_to_storage_stats_key, bucket)
            ## do not automatically reschedule. It creates cascades of failures.
            ##storage.zadd(changed_keys_key, bucket.to_i, bucket)
          end
        end

        def schedule_one_stats_job(bucket = "inf")
          Resque.enqueue(StatsJob, bucket, Time.now.getutc.to_f)
        end

        def pending_buckets
          storage.zrange(changed_keys_key,0,-1)
        end

        def failed_buckets
          storage.smembers(failed_save_to_storage_stats_key)
        end

        def failed_buckets_at_least_once
          storage.smembers(failed_save_to_storage_stats_at_least_once_key)
        end

        private

        def buckets_to_process_script
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
