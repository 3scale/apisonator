module ThreeScale
  module Backend
    module LogRequestStorage
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
        key_service = queue_key_service(transaction[:service_id])
        key_app = queue_key_application(transaction[:service_id], transaction[:application_id])

        value_hash = {
          application_id: transaction[:application_id],
          service_id:     transaction[:service_id],
          log:            transaction[:log],
          usage:          transaction[:usage],
          timestamp:      transaction[:timestamp]
        }

        begin
          value = encode(value_hash)
          decode(value) # XXX is this needed at all?
        rescue Yajl::ParseError
          log = {'request' => 'Error: the log entry could not be stored. Please use UTF8 encoding.',
                 'response' => 'N/A',
                 'code' => 'N/A'}
          value_hash[:log] = log
          value = encode(value_hash)
        end

        storage.lpush(key_service,value)
        storage.ltrim(key_service, 0, LIMIT_PER_SERVICE - 1)
        storage.expire(key_service,REQUEST_TTL)

        storage.lpush(key_app,value)
        storage.ltrim(key_app, 0, LIMIT_PER_APP - 1)
        storage.expire(key_app,REQUEST_TTL)
      end

      def list_by_service(service_id)
        raw_items = storage.lrange(queue_key_service(service_id), 0, -1)
        raw_items.map do |i|
          begin
            decode(i)
          rescue Encoding::InvalidByteSequenceError
            decode(i.force_encoding('UTF-8'))
          end
        end
      end

      def list_by_application(service_id, application_id)
        raw_items = storage.lrange(queue_key_application(service_id, application_id), 0, -1)
        raw_items.map do |i|
          begin
            decode(i)
          rescue Encoding::InvalidByteSequenceError
            decode(i.force_encoding('UTF-8'))
          end
        end
      end

      def count_by_service(service_id)
        storage.llen(queue_key_service(service_id))
      end

      def count_by_application(service_id, application_id)
        storage.llen(queue_key_application(service_id, application_id))
      end

      def delete_by_service(service_id)
        storage.del(queue_key_service(service_id))
      end

      def delete_by_application(service_id, application_id)
        storage.del(queue_key_application(service_id, application_id))
      end

      private

      def queue_key_service(service_id)
        "logs/service_id:#{service_id}"
      end

      def queue_key_application(service_id, application_id)
        "logs/service_id:#{service_id}/app_id:#{application_id}"
      end
    end
  end
end
