require 'cubert/client'

module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      include Memoizer::Decorator
      include Configurable
      extend self

      def store(transaction)
        service = transaction[:service_id]
        if enabled? && (bucket_id = bucket(service))
          connection.create_document(
            body: transaction, bucket: bucket_id, collection: collection
          )
        end
      end

      def store_all(transactions)
        transactions.each { |transaction| store transaction }
      end

      def enabled?
        storage.get(global_lock_key).to_i == 1
      end
      memoize :enabled?

      def global_enable
        storage.set global_lock_key, 1
      end

      def global_disable
        storage.set global_lock_key, 0
      end

      private

      def global_lock_key
        'cubert_request_log_storage_enabled'
      end

      def connection
        @connection ||= Cubert::Client::Connection.new(configuration.cubert.host)
      end

      def bucket(service_id)
        storage.get bucket_id_key(service_id)
      end
      memoize :bucket

      def bucket_id_key(service_id)
        "cubert_request_log_bucket_service_#{service_id}"
      end

      def collection
        'request_logs'
      end
    end
  end
end
