module ThreeScale
  module Backend
    module StatsStorage
      include StorageHelpers
      extend self

      def stats(service_id)
        storage.lrange(stats_list_key(service_id),0,-1)
      end
      
      def stats_count(service_id)
        storage.llen(stats_list_key(service_id))
      end
      
      ## WIP
      def old_stats(service_id)
        list = stats(service_id)
        cold = Array.new
        
        list.each do |key|
          cold << key if ready_for_cold_storage?(key)
        end
        
        values = storage.mget(cold)
        
        cold.each_with_index do|key, index|
          val = values[index]
          if !is_cold_storage_consistent?(key,val)
            ## we have to write to cold storage again (cassandra, or whatever)
            
          else
          end
            
          ## we drop the key from redis  
          storage.del(key)
        end
      end
      
      ## WIP
      def is_cold_storage_consistent?
        return true
      end
      
      ## WIP
      def ready_for_cold_storage?(key)
        return false
      end
      
      def stats_list_key(service_id)
        "service:#{service_id}/stats_keys_list"
      end
      
    end
  end
end
