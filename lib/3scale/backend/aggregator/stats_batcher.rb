require_relative 'stats_info'

module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher

        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          StorageStats.disable!

          (StatsInfo.failed_buckets + StatsInfo.pending_buckets).each do |bucket|
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
      end
    end
  end
end
