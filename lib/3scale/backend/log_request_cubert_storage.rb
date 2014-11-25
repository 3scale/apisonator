module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      extend self

      def store(transaction)
        provider_key = provider(transaction[:service_id])
        if cubert_bucket(provider_key)
          cubert_store provider_key, transaction
        end
      end

      def store_all(transactions)
        transactions.each { |transaction| store transaction }
      end

      def get(provider_key, document_id)
        cubert_connection.get_document(document_id,
          cubert_bucket(provider_key), cubert_collection)
      end

      def list_by_service(service_id)
        cubert_find provider(service_id), {service_id: service_id}
      end

      def list_by_application(service_id, application_id)
        cubert_find provider(service_id),
          {service_id: service_id, application_id: application_id}
      end

      # TODO: Change when counts are available in cubert, currently performs not
      # exactly optimal
      def count_by_service(service_id)
        list_by_service(service_id).size
      end

      # TODO: Change when counts are available in cubert, currently performs not
      # exactly optimal
      def count_by_application(service_id, application_id)
        list_by_application(service_id, application_id).size
      end

      # TODO: move to Cubert, currently deletion not available in Cubert
      def delete_by_service(service_id)
        raise NotImplemnted
      end

      # TODO: move to Cubert, currently deletion not available in Cubert
      def delete_by_application(service_id, application_id)
        raise NotImplemented
      end

      private

      def cubert_find(provider_key, query)
        cubert_connection.find_documents(
          query, cubert_bucket(provider_key), cubert_collection
        ).map(&:body)
      end

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
    end
  end
end
