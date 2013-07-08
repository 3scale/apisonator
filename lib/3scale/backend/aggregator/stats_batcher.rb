module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher
        def changed_keys_bucket_key(bucket)
          "keys_changed:#{bucket}"
        end

        def copied_keys_prefix(bucket)
          "copied:#{bucket}"
        end

        def changed_keys_key
          "keys_changed_set"
        end

        def failed_save_to_mongo_key
          "stats:failed"
        end

        def failed_save_to_mongo_at_least_once_key
          "stats:failed_at_least_once"
        end

        def deactivate_mongo
          storage.del("mongo:active")
        end

        def activate_mongo
          storage.set("mongo:active","1")
        end

        def mongo_active?
          storage.get("mongo:active").to_i == 1
        end

        def disable_mongo
          storage.del("mongo:enabled")
        end

        def enable_mongo
          storage.set("mongo:enabled", "1")
        end

        def mongo_enabled?
          storage.get("mongo:enabled").to_i == 1
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
          disable_mongo
          v = storage.keys("keys_changed:*")
          v.each do |bucket|
            tmp, bucket_time = bucket.split(":")
            keys = storage.smembers(bucket)
            puts "Deleting bucket: #{bucket}, containing #{keys.size} keys" unless options[:silent]==true
            keys.each do |key|
              storage.pipelined do
                storage.del("#{copied_keys_prefix(bucket_time)}:#{key}")
              end
            end
            storage.del(bucket)
          end
          storage.del(changed_keys_key);
          storage.del(failed_save_to_mongo_key)
          storage.del(failed_save_to_mongo_at_least_once_key)
        end

        def stats_bucket_size
          @@stats_bucket_size ||= (configuration.stats.bucket_size || 5)
        end

        ## returns the array of buckets to process that are < bucket
        def get_old_buckets_to_process(bucket = "inf", redis_conn = nil)

          ## there should be very few elements on the changed_keys_key

          redis_conn = storage if redis_conn.nil?

          res = redis_conn.multi do
            redis_conn.zrevrange(changed_keys_key,0,-1)
            redis_conn.zremrangebyscore(changed_keys_key,"-inf","(#{bucket}")
          end

          if (res[1]>=1)
            return res[0].reverse.slice(0..res[1]-1)
          else
            ## nothing was deleted
            return []
          end
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
            storage.srem(failed_save_to_mongo_key, bucket)
          rescue Exception => e
            ## could not write to mongo, reschedule

            begin
              Airbrake.notify(e, parameters: { bucket: bucket })
            rescue Exception => no_airbrake
              ## this is a bit hackish... this will only happens when save_to_mongo blows when
              ## called from a rake task (rake stats:process_failed)
              puts "Error: #{e.inspect}"
            end
            storage.sadd(failed_save_to_mongo_at_least_once_key, bucket)
            storage.sadd(failed_save_to_mongo_key, bucket)
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
          storage.smembers(failed_save_to_mongo_key)
        end

        def failed_buckets_at_least_once
          storage.smembers(failed_save_to_mongo_at_least_once_key)
        end
      end
    end
  end
end
