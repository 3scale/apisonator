module ThreeScale
  module Backend
    class UsageLimit
      include Storable

      PERIODS = [:eternity, :year, :month, :week, :day, :hour, :minute].freeze

      attr_accessor :service_id, :plan_id, :metric_id, :period, :value

      def metric_name
        Metric.load_name(service_id, metric_id)
      end

      # NOTE: validate can ONLY be called with the guarantee that usage_data
      # will have a matching period key.
      def validate(usage_data)
        usage_data[period][metric_id].to_i <= value
      end

      class << self
        include Memoizer::Decorator

        def load_all(service_id, plan_id)
          metric_ids = Metric.load_all_ids(service_id)
          return metric_ids if metric_ids.empty?

          results = []
          with_pairs_and_values service_id, plan_id, metric_ids do |pair, value|
            value and results << new(service_id: service_id,
                                     plan_id: plan_id,
                                     metric_id: pair[0],
                                     period: pair[1],
                                     value: value.to_i)
          end
          results
        end
        memoize :load_all

        def load_value(service_id, plan_id, metric_id, period)
          raw_value = storage.get(key(service_id, plan_id, metric_id, period))
          raw_value and raw_value.to_i
        end

        def save(attributes)
          service_id = attributes[:service_id]
          plan_id = attributes[:plan_id]
          prefix = key_prefix(service_id, plan_id, attributes[:metric_id])
          storage.pipelined do
            PERIODS.each do |period|
              p_val = attributes[period]
              p_val and storage.set(key_for_period(prefix, period), p_val)
            end
            Service.incr_version(service_id)
          end
          clear_cache(service_id, plan_id)
        end

        def delete(service_id, plan_id, metric_id, period)
          storage.pipelined do
            storage.del(key(service_id, plan_id, metric_id, period))
            Service.incr_version(service_id)
          end
          clear_cache(service_id, plan_id)
        end

        private

        def key(service_id, plan_id, metric_id, period)
          key_for_period(key_prefix(service_id, plan_id, metric_id), period)
        end

        # NOTE: metric_id == nil is an accepted value
        def key_prefix(service_id, plan_id, metric_id = :none)
          "usage_limit/service_id:#{service_id}/plan_id:#{plan_id}/metric_id:" \
            "#{"#{metric_id}/" if metric_id != :none}"
        end

        # receives a key prefix and a pair [metric_id, period]
        def key_for_pair(key_pre, pair)
          encode_key("#{key_pre}#{pair[0]}/#{pair[1]}")
        end

        def key_for_period(key_pre, period)
          encode_key(key_pre + period.to_s)
        end

        # yields [pair(metric_id, period), value]
        def with_pairs_and_values(service_id, plan_id, metric_ids, &blk)
          pairs, values = get_pairs_and_values_for service_id, plan_id, metric_ids
          pairs.zip values, &blk
        end

        def get_pairs_and_values_for(service_id, plan_id, metric_ids)
          pairs, keys = generate_pairs_and_keys_for service_id, plan_id, metric_ids

          [pairs, storage.mget(keys)]
        end

        def generate_pairs_and_keys_for(service_id, plan_id, metric_ids)
          pairs = []
          keys = []

          prefix = key_prefix service_id, plan_id
          metric_ids.product PERIODS do |pair|
            pairs << pair
            keys << key_for_pair(prefix, pair)
          end

          [pairs, keys]
        end

        def clear_cache(service_id, plan_id)
          Memoizer.clear(Memoizer.build_key(self, :load_all, service_id, plan_id))
        end
      end

    end
  end
end
