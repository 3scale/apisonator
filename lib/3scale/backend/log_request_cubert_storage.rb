module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      extend self

      LIMIT_PER_APP = 20
      LIMIT_PER_SERVICE = 200

      REQUEST_TTL = 3600*24*10

      ENTRY_MAX_LEN_REQUEST = 1024
      ENTRY_MAX_LEN_RESPONSE = 4096
      ENTRY_MAX_LEN_CODE = 32
      TRUNCATED = " ...TRUNCATED"

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
        provider_key = provider(transaction[:service_id])
        if cubert_bucket(provider_key)
          cubert_store provider_key, transaction
        end
      end

      def get(provider_key, document_id)
        cubert_connection.get_document(document_id,
          cubert_bucket(provider_key), cubert_collection)
      end

      def list_by_service(service_id)
        provider_key = provider(service_id)
        cubert_connection.find_documents(
          {service_id: service_id},
          cubert_bucket(provider_key),
          cubert_collection
        ).map(&:body)
      end

      # TODO: move to Cubert
      def list_by_application(service_id, application_id)
        raw_items = storage.lrange(queue_key_application(service_id, application_id), 0, -1)
        raw_items.map(&method(:decode))
      end

      # TODO: move to Cubert
      def count_by_service(service_id)
        storage.llen(queue_key_service(service_id))
      end

      # TODO: move to Cubert
      def count_by_application(service_id, application_id)
        storage.llen(queue_key_application(service_id, application_id))
      end

      # TODO: move to Cubert
      def delete_by_service(service_id)
        storage.del(queue_key_service(service_id))
      end

      # TODO: move to Cubert
      def delete_by_application(service_id, application_id)
        storage.del(queue_key_application(service_id, application_id))
      end

      private

      def cubert_connection
        Cubert::Client::Connection.new('http://localhost:8080')
      end

      def cubert_store(provider_key, data)
        cubert_connection.create_document body: data,
          bucket: cubert_bucket(provider_key), collection: 'request_logs'
      end

      def cubert_bucket(provider_key)
        storage.get(bucket_id_key(provider_key))
      end

      def bucket_id_key(provider_key)
        "cubert_bucket_provider_#{provider_key}"
      end

      def cubert_collection
        'request_logs'
      end

      def provider(service_id)
        Service.load_by_id!(service_id).provider_key
      end

      def queue_key_service(service_id)
        "logs/service_id:#{service_id}"
      end

      def queue_key_application(service_id, application_id)
        "logs/service_id:#{service_id}/app_id:#{application_id}"
      end
    end
  end
end
