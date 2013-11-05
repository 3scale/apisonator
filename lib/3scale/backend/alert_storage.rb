module ThreeScale
  module Backend
    module AlertStorage
      include StorageHelpers
      extend self

      LIMIT_SERVICE = 2000

      def store(alert)
        key_service = queue_key(alert[:service_id])
        card        = storage.scard(key_service)

        storage.pipelined do
          storage.sadd(key_service,
                       encode(id:              alert[:id],
                              service_id:      alert[:service_id],
                              application_id:  alert[:application_id],
                              utilization:     alert[:utilization],
                              max_utilization: alert[:max_utilization],
                              limit:           alert[:limit],
                              timestamp:       alert[:timestamp]))

          if card + 1 > LIMIT_SERVICE
            storage.srem(key_service, storage.smembers(key_service).last)
          end
        end
      end

      def list(service_id)
        raw_items = storage.eval(atomic_list_script, keys: [queue_key(service_id)])
        raw_items.map(&method(:decode))
      end

      def queue_key(service_id)
        "alerts/service_id:#{service_id}"
      end

      private

      def atomic_list_script
        <<EOF
local items = redis.call('smembers', KEYS[1])
redis.call('del', KEYS[1])

return items
EOF
      end
    end
  end
end
