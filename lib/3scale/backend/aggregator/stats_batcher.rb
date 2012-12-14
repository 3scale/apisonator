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
        
        def changed_keys_key()
          "keys_changed_set"
        end
        
        def failed_save_to_cassandra_key
          "stats:failed"
        end
        
        def failed_save_to_cassandra_at_least_once_key
          "stats:failed_at_least_once"
        end
        
        def deactivate_cassandra()
          storage.del("cassandra:active")
        end
        
        def activate_cassandra()
          storage.set("cassandra:active","1")
        end
        
        def cassandra_active?
          storage.get("cassandra:active").to_i == 1
        end
        
        def disable_cassandra()
          storage.del("cassandra:enabled")
        end
        
        def enable_cassandra()
          storage.set("cassandra:enabled","1")
        end
        
        def cassandra_enabled?
          storage.get("cassandra:enabled").to_i == 1
        end
        
        def pending_buckets_size()
          storage.zcard(changed_keys_key)
        end
        
        def pending_keys_by_bucket()
          result = {}
          pending_buckets.each do |b| 
            result[b] = storage.scard(changed_keys_bucket_key(b))
          end
          result
        end
        
        
        def check_counters_only_as_rake(service_id, application_id, metric_id, timestamp) 
          results = {:redis => {}, :cassandra => {}}
          
          service_prefix     = service_key_prefix(service_id)
          application_prefix = application_key_prefix(service_prefix, application_id)
          application_metric_prefix = metric_key_prefix(application_prefix, metric_id)
        
          [:eternity, :month, :week, :day, :hour, :minute].each do |gra| 
            redis_key = counter_key(application_metric_prefix, gra, timestamp)
            results[:redis][gra] = storage.get(redis_key)
            cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(redis_key)
            results[:cassandra][gra] = storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
          end
          
          return results  
        end
        
        def delete_all_buckets_and_keys_only_as_rake!(options = {})
          disable_cassandra()
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
          storage.del(failed_save_to_cassandra_key)
          storage.del(failed_save_to_cassandra_at_least_once_key)
        end
        
        def stats_bucket_size
          @@stats_bucket_size ||= (configuration.stats.bucket_size || 5)
        end
        
        def repeated_batches
          storage_cassandra.repeated_batches
        end
        
        def undo_repeated_batch(batch_str)
          storage_cassandra.undo_execute_batch(batch_str)
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
        
        def time_bucket_already_inserted?(bucket)
          storage_cassandra.time_bucket_already_inserted?(bucket)
        end
        
        
        def save_to_cassandra(bucket) 
          
          ## FIXME: this has to go aways, just temporally to check for concurrency issues
          storage.pipelined do 
            storage.lpush("temp_list","#{bucket}-#{Time.now.utc}-#{Thread.current.object_id}")
            storage.ltrim("temp_list",0,1000-1)
          end

          str = ""

          begin 
            
            keys_that_changed = storage.smembers(changed_keys_bucket_key(bucket))

            return if keys_that_changed.nil? || keys_that_changed.empty?

            ## need to fetch the values from the copies, not the originals
            copied_keys_that_changed = keys_that_changed.map {|item| "#{copied_keys_prefix(bucket)}:#{item}"}  

            values = storage.mget(*copied_keys_that_changed)
          
            ## this is to fill the Stats, where col_key is timestamp, and row_key is stats/service/cinstance
      
            single_key_by_batch = Hash.new
            single_value_by_batch = Hash.new
          
            keys_that_changed.each_with_index do |key, i|
              
              row_key, col_key = redis_key_2_cassandra_key(key)
              
              single_key_by_batch[row_key] ||= Array.new
              single_value_by_batch[row_key] ||= Array.new
            
              single_key_by_batch[row_key] << col_key
              single_value_by_batch[row_key] << values[i].to_i
            end
      
            single_key_by_batch.keys.each do |row_key|
              str << StorageCassandra.add2cql(:Stats, row_key, single_value_by_batch[row_key], single_key_by_batch[row_key]) << " "
            end
      
            ## this is to fill the StatsInverted were row_key is service_id/timestamp, and col_key is cinstance/metric/...
            
            single_key_by_batch = Hash.new
            single_value_by_batch = Hash.new
            
            keys_that_changed.each_with_index do |key, i|
              
              row_key, col_key = redis_key_2_cassandra_key_inverted(key)
              
              if !row_key.nil? && !col_key.nil?
                        
                single_key_by_batch[row_key] ||= Array.new
                single_value_by_batch[row_key] ||= Array.new
            
                single_key_by_batch[row_key] << col_key
                single_value_by_batch[row_key] << values[i].to_i
              end
              
            end
                    
            single_key_by_batch.keys.each do |row_key|
              str << StorageCassandra.add2cql(:StatsInverted, row_key, single_value_by_batch[row_key], single_key_by_batch[row_key]) << " "
            end
          
            
            storage_cassandra.execute_batch(bucket, str); 
            
            ## now we have to clean up the data in redis that has been processed
            storage.pipelined do
              copied_keys_that_changed.each do |item|
                storage.del(item)
              end
              storage.del(changed_keys_bucket_key(bucket))
              storage.srem(failed_save_to_cassandra_key, bucket)
            end

          rescue Exception => e
            ## could not write to cassandra, reschedule
            
            begin
              Airbrake.notify(e, parameters: { bucket: bucket, cql: str })
            rescue Exception => no_airbrake
              ## this is a bit hackish... this will only happens when save_to_cassandra blows when
              ## called from a rake task (rake stats:process_failed) 
              puts "Error: #{e.inspect}"
            end
            
            storage.sadd(failed_save_to_cassandra_at_least_once_key, bucket)
            storage.sadd(failed_save_to_cassandra_key, bucket)
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
          storage.smembers(failed_save_to_cassandra_key)
        end
        
        def failed_buckets_at_least_once
          storage.smembers(failed_save_to_cassandra_at_least_once_key)
        end
        
      end
    end
  end
end
