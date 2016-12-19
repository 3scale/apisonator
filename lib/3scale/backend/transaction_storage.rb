module ThreeScale
  module Backend
    class TransactionStorage
      LIMIT = 50
      private_constant :LIMIT

      class << self
        include StorageHelpers

        def store_all(transactions)
          # We store at most LIMIT transactions. As we call 'ltrim' when a
          # transaction is stored, it makes no sense to store more than the
          # limit defined. The first transactions that are stored would get
          # 'trimmed' quickly, thus wasting resources of the Redis cluster.
          transactions.take(LIMIT).each_slice(PIPELINED_SLICE_SIZE) do |slice|
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

        def delete_all(service_id)
          storage.del(queue_key(service_id))
        end

        private

        def queue_key(service_id)
          "transactions/service_id:#{service_id}"
        end
      end
    end
  end
end
