
module ThreeScale
  module Backend
    module AlertStorage
      include StorageHelpers
      extend self

      LIMIT_SERVICE = 2000
      
      def store(alert)

        key_service = queue_key(alert[:service_id])
        card = storage.scard(key_service)

        storage.pipelined do
          storage.sadd(key_service,
                       encode(:id             => alert[:id],
                              :service_id     => alert[:service_id],
                              :application_id => alert[:application_id],
                              :utilization    => alert[:utilization],
                              :max_utilization=> alert[:max_utilization],
                              :limit          => alert[:limit],
                              :timestamp      => alert[:timestamp]))

          storage.srem(key_service, storage.smembers(key_service).last) if card + 1 > LIMIT_SERVICE
        end
        
      end
        
      def list(service_id)
        key = queue_key(service_id)
        raw_items, tmp = storage.multi do
          storage.smembers(key)
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
