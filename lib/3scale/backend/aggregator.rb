module ThreeScale
  module Backend
    module Aggregator
      include Core::StorageKeyHelpers
      extend self

      # TODO: clean this up a bit

      def aggregate(transaction)
        service_prefix  = service_key_prefix(transaction[:service_id])
        contract_prefix = contract_key_prefix(service_prefix, transaction[:contract_id])

        timestamp = transaction[:timestamp]

        transaction[:usage].each do |metric_id, value|
          service_metric_prefix = metric_key_prefix(service_prefix, metric_id)

          increment(service_metric_prefix, :eternity,   nil,       value)
          increment(service_metric_prefix, :month,      timestamp, value)
          increment(service_metric_prefix, :week,       timestamp, value)
          increment(service_metric_prefix, :day,        timestamp, value)
          increment(service_metric_prefix, 6 * 60 * 60, timestamp, value)
          increment(service_metric_prefix, :hour,       timestamp, value)
          increment(service_metric_prefix, 2 * 60,      timestamp, value)

          contract_metric_prefix = metric_key_prefix(contract_prefix, metric_id)

          increment(contract_metric_prefix, :eternity,   nil,       value)
          increment(contract_metric_prefix, :year,       timestamp, value)
          increment(contract_metric_prefix, :month,      timestamp, value)
          increment(contract_metric_prefix, :week,       timestamp, value)
          increment(contract_metric_prefix, :day,        timestamp, value)
          increment(contract_metric_prefix, 6 * 60 * 60, timestamp, value)
          increment(contract_metric_prefix, :hour,       timestamp, value)
          increment(contract_metric_prefix, :minute,     timestamp, value, :expires_in => 60)
        end

        update_contract_set(service_prefix, transaction[:contract_id])
      end

      private

      def service_key_prefix(service_id)
        # The { ... } is the key tag. See redis docs for more info about key tags.
        "stats/{service:#{service_id}}"
      end

      def contract_key_prefix(prefix, contract_id)
        "#{prefix}/cinstance:#{contract_id}"
      end

      def metric_key_prefix(prefix, metric_id)
        "#{prefix}/metric:#{metric_id}"
      end

      def increment(prefix, granularity, timestamp, value, options = {})
        key = counter_key(prefix, granularity, timestamp)

        storage.incrby(key, value)
        storage.expire(key, options[:expires_in]) if options[:expires_in]
      end
      
      def counter_key(prefix, granularity, timestamp)
        time_part = if granularity == :eternity
                      :eternity
                    else
                      time = timestamp.beginning_of_cycle(granularity)
                      "#{granularity}:#{time.to_compact_s}"
                    end

        "#{prefix}/#{time_part}"
      end

      def update_contract_set(prefix, contract_id)
        key = encode_key("#{prefix}/cinstances")
        storage.sadd(key, encode_key(contract_id))
      end

      def storage
        Storage.instance
      end
    end
  end
end
