module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher
      
        def changed_keys_bucket_key(bucket)
          "keys_changed:#{bucket}"
        end

        def changed_keys_key()
          "keys_changed_set"
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
        
        ## returns the array of buckets to process that are < bucket
        def get_old_buckets_to_process(bucket = "inf")
          
          ## there should be very few elements on the changed_keys_key
    
          res = storage.multi do
            storage.zrevrange(changed_keys_key,0,-1)
            storage.zremrangebyscore(changed_keys_key,"-inf","(#{bucket}")
          end
          
          if (res[1]>=1)
            return res[0].reverse.slice(0..res[1]-1)
          else
            ## nothing was deleted
            return []
          end
          
        end
        
        def save_to_cassandra(bucket) 
          
          keys_that_changed = storage.smembers(changed_keys_bucket_key(bucket))

          return if keys_that_changed.nil? || keys_that_changed.empty?

          ## need to fetch the values from the copies, not the originals
          copied_keys_that_changed = keys_that_changed.map {|item| "#{bucket}:#{item}"}  

          values = storage.mget(*copied_keys_that_changed)
                
          str = "BEGIN BATCH "
          keys_that_changed.each_with_index do |key, i|
            row_key, col_key = redis_key_2_cassandra_key(key)
            str << add2cql(:Stats, row_key, values[i], col_key) << " "
          end
          str << "APPLY BATCH;"
          
          
          begin
            storage_cassandra.execute(str);
            
            ## now we have to clean up the data in redis that has been processed
            storage.pipelined do
              copied_keys_that_changed.each do |item|
                storage.del(item)
              end
              storage.del(changed_keys_bucket_key(bucket))
            end
            
          rescue Exception => e
            ## could not write to cassandra, reschedule
            storage.zadd(changed_keys_key, bucket.to_i, bucket)        
          end
          
        end
        
        def schedule_one_stats_job(bucket = "inf")
          Resque.enqueue(StatsJob, bucket)
        end
        
        def pending_buckets
          storage.zrange(changed_keys_key,0,-1)    
        end
        
        def add2cql(column_family, row_key, value, col_key)
          str = "UPDATE " << column_family.to_s
          str << " SET '" << col_key << "'='" << col_key << "' + " << value.to_s
          str << " WHERE key = '" << row_key << "';"
        end

        ## this is a fake CQL statement that does an set value of a counter
        ## we better store it as string since it might be processed on a delayed matter
        ## is cassandra is down (see Aggregator::process_batch_sql)
        def set2cql(column_family, row_key, value, col_key)
          str = "!SET " << column_family.to_s << " " << row_key << " " << col_key << " " << value.to_s
        end

        def get2cql(column_family, row_key, col_key)
          str = "SELECT '" << col_key << "'"
          str << " FROM '" << column_family.to_s << "'"
          str << " WHERE key = '" + row_key + "';"
        end
        
      end
    end
  end
end
