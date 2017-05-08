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
              # we keep a hash of keys for services touched (they are lists)
              # this way we avoid issuing one ltrim per transaction, since
              # usually such ltrims act always on few lists.
              lists = {}
              slice.each do |transaction|
                key = store_only(transaction)
                lists[key] = true
              end
              lists.keys.each do |key|
                trim_storage(key)
              end
            end
          end
        end

        def store(transaction)
          trim_storage(store_only(transaction))
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

        def trim_storage(key)
          storage.ltrim(key, 0, LIMIT - 1)
        end

        # this method is meant to avoid cleaning up to optimize the amount of
        # commands in a pipeline, as used in store_all.
        def store_only(transaction)
          key = queue_key(transaction.service_id)

          storage.lpush(key,
                        encode(application_id: transaction.application_id,
                               usage:          transaction.usage,
                               timestamp:      transaction.timestamp))
          key
        end

        def queue_key(service_id)
          "transactions/service_id:#{service_id}"
        end
      end
    end
  end
end
