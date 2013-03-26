module ThreeScale
  module Backend
    module StatsStorage
      include StorageHelpers
      extend self

      def stats(service_id)
        storage.smembers(stats_set_key(service_id))
      end
      
      def stats_count(service_id)
        storage.scard(stats_set_key(service_id))
      end
      
      def old_stats(service_id)
        list = stats(service_id)
        cold = Array.new
        
        list.each do |key|
          if ready_for_cold_storage?(key)
            cold << key
          end  
        end
      end
      
      def ready_for_cold_storage?(key)
        return false
      end
      
      
      def stats_set_key(service_id)
        "service:#{service_id}/stats_keys_set"
      end
      
    end
  end
end
