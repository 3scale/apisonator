require 'cubert/client'
require '3scale/backend/use_cases/cubert_service_management_use_case'

module ThreeScale
  module Backend
    module LogRequestCubertStorage
      include StorageHelpers
      include Memoizer::Decorator
      include Configurable
      extend self

      def store transaction
        service_id = transaction[:service_id]
        if enabled?(service_id) && bucket_id = bucket(service_id)
          transaction[:log]["code"] = transaction[:log]["code"].to_i
          begin
            connection.create_document(
              body: transaction, bucket: bucket_id, collection: collection
            )
          rescue JSON::GeneratorError
            transaction[:log] = {
              'request' => 'Error: the log entry could not be stored. Please use UTF8 encoding.',
              'response' => 'N/A',
              'code' => 'N/A'
            }
            connection.create_document(
              body: transaction, bucket: bucket_id, collection: collection
            )
          rescue Cubert::Client::ServiceUnavailable
            # Cubert infrastructure is not very stable yet and sometimes cubert
            # servers are not available. By the moment, we can ignore these
            # errors and discard the log.
          end
        end
      end

      def store_all transactions
        transactions.each { |transaction| store transaction }
      end

      private

      def connection
       CubertServiceManagementUseCase.connection
      end

      def enabled? service_id
        cubert(service_id).enabled?
      end
      memoize :enabled?

      def bucket service_id
        cubert(service_id).bucket
      end
      memoize :bucket

      def cubert service_id
        CubertServiceManagementUseCase.new service_id
      end

      def collection
        'request_logs'
      end
    end
  end
end
