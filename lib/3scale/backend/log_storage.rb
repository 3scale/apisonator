module ThreeScale
  module Backend
    module LogStorage
      include StorageHelpers
      extend self

      LIMIT_PER_APP = 20
      LIMIT_PER_SERVICE = 200

      def store_all(transactions)
        transactions.each_slice(PIPELINED_SLICE_SIZE) do |slice|
          storage.pipelined do
            slice.each do |transaction|
              store(transaction)
            end
          end
        end
      end

      def store(transaction)
        key_service = queue_key_service(transaction[:service_id])
        key_app = queue_key_application(transaction[:service_id], transaction[:application_id])

        storage.lpush(key_service, 
                      encode(:application_id => transaction[:application_id],
                             :log            => transaction[:log],
                             :timestamp      => transaction[:timestamp]))
        storage.ltrim(key_service, 0, LIMIT_PER_SERVICE - 1)

        storage.lpush(key_app, 
                      encode(:application_id => transaction[:application_id],
                             :log            => transaction[:log],
                             :timestamp      => transaction[:timestamp]))
        storage.ltrim(key_app, 0, LIMIT_PER_APP - 1)

        ## FIXME: add the timeouts

      end

      def list_by_service(service_id)
        raw_items = storage.lrange(queue_key_service(service_id), 0, -1)
        raw_items.map(&method(:decode))
      end

      def list_by_application(service_id, application_id)
        raw_items = storage.lrange(queue_key_application(service_id, application_id), 0, -1)
        raw_items.map(&method(:decode))
      end


      private

      def queue_key_service(service_id)
        "logs/service_id:#{service_id}"
      end

      def queue_key_application(service_id, application_id)
        "logs/service_id:#{service_id}/app_id:#{application_id}"
      end

    end
  end
end
