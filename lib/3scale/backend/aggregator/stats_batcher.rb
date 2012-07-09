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
          storage.scard(changed_keys_key)
        end
        
        def get_oldest_bucket_blocking(bucket)
          
          ## there should be very few elements on the changed_keys_key
          
          sorted_buckets = storage.smembers(changed_keys_key).sort
          return nil if sorted_buckets.empty? || sorted_buckets.first < bucket
          
          storage.watch(changed_keys_key)
          key = sorted_buckets.first
          
          res = storage.multi do
            storage.srem(changed_keys_key,key)
          end
          
          ## this should never happen, it means that the element is not on the set
          ## but then, the multi should have returned null. Comment it when on production
          raise Exception, "Something very fishy is happening" if !res.nil? && res.first==0
          
          ## returns the bucket that you get the lock on, or nil if there is no
          ## buckets to be worked on, either because there were none, or because
          ## there were (!buckets.empty?) but someone has modified the set
          
          if res.nil? 
            return nil 
          else
            return key
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
            puts "error in cassandra"
            puts e
            storage.sadd(changed_keys_key, bucket)        
          end
          
        end
        
        def run_stats_for_tests
          return unless cassandra_enabled?
          
          while (pending_buckets_size()>0)
            cont = pending_buckets_size()   
            bucket_to_save = get_oldest_bucket_blocking("")
            save_to_cassandra(bucket_to_save)          
            raise "Stuck in an infinite loop: temporal, will blow when cassandra connection fails" if pending_buckets_size() == cont  
          end
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
