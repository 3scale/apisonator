module ThreeScale
  module Backend
    module Aggregator
      module StatsBatcher
      
        def failed_batch_cql_key
          "cassandra:failed"
        end
      
        def unprocessable_batch_cql_key
          "cassandra:unprocessable"
        end
        
        def failed_batch_cql_size
          storage.llen(failed_batch_cql_key)
        end
      
        def unprocessable_batch_cql_size
          storage.llen(unprocessable_batch_cql_key)
        end  
        
        def delete_failed_batch_cql
          storage.del(failed_batch_cql_key)
        end
        
        def delete_unprocessable_batch_cql
          storage.del(unprocessable_batch_cql_key)
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
        
        def enqueue_failed_batch_cql(pending)
        
          return nil if pending.nil? or pending.empty?
        
          storage.rpush(failed_batch_cql_key, 
                         encode(:payload   => pending,
                                :timestamp => Time.now.getutc)) 
        
        end
        
        def process_failed_batch_cql(options = {})
          
          while item = storage.lpop(failed_batch_cql_key)
            begin
              process_batch_cql(decode(item)[:payload], :already_on_pending => true)
            rescue Exception => e
              ## if there is an error give an airbreak but
              ## put the item back to the queue so it's not
              storage.rpush(unprocessable_batch_cql_key,item)
              raise e
            end
            
            break if options[:all].nil? || options[:all] != true
          end
          
        end
      
        def process_batch_cql(batch_cql, options = {}) 
       
          return nil if batch_cql.nil? or batch_cql.empty?
        
          pending = batch_cql.clone()
        
          str = "BEGIN BATCH "
          atleastone = false
        
          while statement = batch_cql.shift
            
            if (statement[0]=='!') 
              ## a set operation. We need first to run the current batch.
            
              if atleastone
                ## a set operation. We need first to run the current batch if it already
                ## have increments to get the proper state from the upcoming read 
                str << "APPLY BATCH;"
              
                begin
                  storage_cassandra.execute(str)
                  pending = batch_cql.clone()
                  str = "BEGIN BATCH "
                  atleastone = false
                                
                rescue Exception => e
                  ##could now write to cassandra
                  ## save the pending array to redis if it was not already on pending
                  if options[:already_on_pending]
                    raise e
                  else
                    enqueue_failed_batch_cql(pending)
                    return nil
                  end 
                end
              
              end
            
              begin
                ## this statement is build in StorageCassandra::set2cql
                foo, col_family, row_key, col_key, value = statement.split(" ")
            
                ## this is a total anti-pattern of cassandra
                old_value = storage_cassandra.get(col_family,row_key,col_key)
                old_value = 0 if old_value.nil?
                storage_cassandra.add(col_family,row_key, value.to_i - old_value.to_i ,col_key)
            
                pending = batch_cql.clone()
              
              rescue Exception => e
                ## could not write to cassandra
                if options[:already_on_pending]
                  raise e
                else
                  enqueue_failed_batch_cql(pending) 
                  return nil
                end
              end
               
              ##we have done the set, now we can continue with a the sub-batch from this point on
          
            else
              ## not a set operation, simple incr/decr
              str << statement
              atleastone = true
            end
                   
          end
          
          if atleastone
            str << "APPLY BATCH;"
            begin
              storage_cassandra.execute(str);
              pending = batch_cql.clone()
            rescue Exception => e
              ## could not write to cassandra
              if options[:already_on_pending]
                raise e
              else
                enqueue_failed_batch_cql(pending)
                return nil
              end
            end
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
