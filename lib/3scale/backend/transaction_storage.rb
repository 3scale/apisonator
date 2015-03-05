module ThreeScale
  module Backend
    module TransactionStorage
      include StorageHelpers
      extend self

      LIMIT = 50

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
        key = queue_key(transaction.service_id)

        storage.lpush(key,
                      encode(application_id: transaction.application_id,
                             usage:          transaction.usage,
                             timestamp:      transaction.timestamp))
        storage.ltrim(key, 0, LIMIT - 1)
      end

      def list(service_id)
        raw_items = storage.lrange(queue_key(service_id), 0, -1)
        raw_items.map(&method(:decode))
      end

      private

      def queue_key(service_id)
        "transactions/service_id:#{service_id}"
      end
    end
  end
end
