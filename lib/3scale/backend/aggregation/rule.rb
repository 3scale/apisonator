module ThreeScale
  module Backend
    module Aggregation
      class Rule
        include StorageKeyHelpers

        # The storage key of the stats value consists of several name:value parts. The part
        # with this name will be used as key tag. 
        #
        # Please refer to the redis docs for more info about key tags.
        TAG = :service

        def initialize(*args, &block)
          @options = args.last.is_a?(Hash) ? args.pop : {}
          @keys = args
        end

        def aggregate(data)
          update_accumulator(data)
          update_source_set(data)
        end

        def expires_in
          @options[:expires_in]
        end

        def volatile?
          !expires_in.nil?
        end

        private

        def update_accumulator(data)
          data[:usage].each do |metric_id, value|
            key = accumulator_key(data, metric_id)

            storage.incrby(key, value)
            storage.expire(key, expires_in) if volatile?
          end
        end

        def update_source_set(data)
          return if @keys.size < 2

          source_name  = @keys.last
          source_value = data[source_name]

          key = source_set_key_prefix(data) + '/' +
                source_name.to_s + '_set'

          storage.sadd(key, encode_key(source_value.to_s))
        end

        def accumulator_key(data, metric_id)
          encode_key(source_key_component(data, @keys) + '/' +
                     metric_key_component(metric_id) + '/' +
                     granularity_key_component(data))
        end

        def source_set_key_prefix(data)
          source_key_component(data, @keys[0..-2])
        end

        def source_key_component(data, keys)
          keys.inject(:stats) do |memo, name|
            "#{memo}/#{tagify(name, data[name])}"
          end
        end

        def tagify(name, value)
          result = "#{name}:#{value}"
          result = "{#{result}}" if name == TAG
          result
        end

        def metric_key_component(id)
          "metric:#{id}"
        end

        def granularity_key_component(data)
          if granularity == :eternity
            "eternity"
          else
            cycle = data[:timestamp].beginning_of_cycle(granularity)
            "#{granularity}:#{cycle.to_compact_s}"
          end
        end

        def granularity
          Aggregation.normalize_granularity(@options[:granularity])
        end

        def storage
          Storage.instance
        end
      end
    end
  end
end
