
module ThreeScale
  module Backend
    module AlertStorage
      include StorageHelpers
      extend self

      LIMIT_SERVICE = 2000
      
      def store(alert)

        key_service = queue_key(alert[:service_id])

        storage.pipelined do

          storage.lpush(key_service, 
                        encode(:id             => alert[:id],
                               :service_id     => alert[:service_id],
                               :application_id => alert[:application_id],
                               :utilization    => alert[:utilization],
                               :max_utilization    => alert[:max_utilization],
                               :limit          => alert[:limit],
                               :timestamp      => alert[:timestamp]))

          storage.ltrim(key_service, 0, LIMIT_SERVICE - 1)

        end
      end
        
      def list(service_id)
        key = queue_key(service_id)
        raw_items, tmp = storage.multi do
          storage.lrange(key, 0, -1)
          storage.del(key)
        end
        raw_items.map(&method(:decode))
      end

  
      def queue_key(service_id)
        "alerts/service_id:#{service_id}"
      end


    end
  end
end
