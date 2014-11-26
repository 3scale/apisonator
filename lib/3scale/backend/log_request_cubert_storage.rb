module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      extend self

      def store(transaction)
        service = transaction[:service_id]
        if cubert_bucket(service)
          cubert_store service, transaction
        end
      end

      def store_all(transactions)
        transactions.each { |transaction| store transaction }
      end

      def get(service_id, document_id)
        cubert_connection.get_document document_id, cubert_bucket(service_id),
          cubert_collection
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

      def cubert_find(service_id, query)
        cubert_connection.find_documents(
          query, cubert_bucket(service_id), cubert_collection
        ).map(&:body)
      end

      def cubert_connection
        Cubert::Client::Connection.new('http://localhost:8080')
      end

      def cubert_store(service_id, data)
        cubert_connection.create_document body: data,
          bucket: cubert_bucket(service_id), collection: 'request_logs'
      end

      def cubert_bucket(service_id)
        storage.get(bucket_id_key(service_id))
      end

      def bucket_id_key(service_id)
        "cubert_bucket_service_#{service_id}"
      end

      def cubert_collection
        'request_logs'
      end
    end
  end
end
