module ThreeScale
  module Backend
    module Aggregation
      include StorageKeyHelpers
      extend self

      def aggregate(transaction)
        service_prefix = "stats/{service:#{transaction[:service]}}"

        increment(transaction, service_prefix, :eternity)
        increment(transaction, service_prefix, :month)
        increment(transaction, service_prefix, :week)
        increment(transaction, service_prefix, :day)
        increment(transaction, service_prefix, 6 * 60 * 60)
        increment(transaction, service_prefix, :hour)
        increment(transaction, service_prefix, 2 * 60)

        contract_prefix = service_prefix + "/cinstance:#{transaction[:cinstance]}"

        increment(transaction, contract_prefix, :eternity)
        increment(transaction, contract_prefix, :year)
        increment(transaction, contract_prefix, :month)
        increment(transaction, contract_prefix, :week)
        increment(transaction, contract_prefix, :day)
        increment(transaction, contract_prefix, 6 * 60 * 60)
        increment(transaction, contract_prefix, :hour)
        increment(transaction, contract_prefix, :minute, :expires_in => 60)

        update_contract_set(transaction)
      end

      private

      def increment(transaction, prefix, granularity, options = {})
        transaction[:usage].each do |metric_id, value|
          key = counter_key(prefix, metric_id, granularity, transaction[:timestamp])

          storage.incrby(key, value)
          storage.expire(key, options[:expires_in]) if options[:expires_in]
        end
      end

      def update_contract_set(transaction)
        key = encode_key("stats/{service:#{transaction[:service]}}/cinstance_set")
        storage.sadd(key, encode_key(transaction[:cinstance]))
      end

      def counter_key(prefix, metric_id, granularity, timestamp)
        time_part = if granularity == :eternity
                      :eternity
                    else
                      time = timestamp.beginning_of_cycle(granularity)
                      "#{granularity}:#{time.to_compact_s}"
                    end

        "#{prefix}/metric:#{metric_id}/#{time_part}"
      end

      def storage
        Storage.instance
      end
    end
  end
end
