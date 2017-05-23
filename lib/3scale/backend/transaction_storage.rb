module ThreeScale
  module Backend
    class TransactionStorage
      LIMIT = 50
      private_constant :LIMIT

      class << self
        include StorageHelpers

        # Note: this method assumes that all the transactions belong to the
        # same service
        def store_all(transactions)
          store_for_service(transactions.first.service_id, transactions)
        end

        def store(transaction)
          store_for_service(transaction.service_id, [transaction])
        end

        def list(service_id)
          raw_items = storage.lrange(queue_key(service_id), 0, -1)
          # this avoids "seeing" a transient state (ie. in a pipeline) in which
          # the list is being added to but still not trimmed.
          raw_items.take(LIMIT).map(&method(:decode))
        end

        def delete_all(service_id)
          storage.del(queue_key(service_id))
        end

        private

        def store_for_service(service_id, transactions)
          key = queue_key(service_id)

          # We store at most LIMIT transactions. As we call 'ltrim' when a
          # transaction is stored, it makes no sense to store more than the
          # limit defined. The first transactions that are stored would get
          # 'trimmed' quickly, thus wasting resources of the Redis cluster.
          transactions.take(LIMIT).each_slice(PIPELINED_SLICE_SIZE) do |slice|
            encoded_transactions = slice.map do |transaction|
              encoded(transaction)
            end

            storage.pipelined do
              storage.lpush(key, encoded_transactions)
              storage.ltrim(key, 0, LIMIT - 1)
            end
          end
        end

        def encoded(transaction)
          encode(application_id: transaction.application_id,
                 usage: transaction.usage,
                 timestamp: transaction.timestamp)
        end

        def queue_key(service_id)
          "transactions/service_id:#{service_id}"
        end
      end
    end
  end
end
