module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      extend self

      def store(transaction)
        service = transaction[:service_id]
        if bucket(service)
          connection.create_document(
            body: transaction, bucket: bucket(service), collection: collection
          )
        end
      end

      def store_all(transactions)
        transactions.each { |transaction| store transaction }
      end

      private

      def connection
        Cubert::Client::Connection.new('http://localhost:8080')
      end

      def bucket(service_id)
        storage.get(bucket_id_key(service_id))
      end

      def bucket_id_key(service_id)
        "cubert_bucket_service_#{service_id}"
      end

      def collection
        'request_logs'
      end
    end
  end
end
