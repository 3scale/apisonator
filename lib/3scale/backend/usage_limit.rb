module ThreeScale
  module Backend
    class UsageLimit
      include Storable

      PERIODS = [:eternity, :year, :month, :week, :day, :hour, :minute].freeze

      attr_accessor :service_id, :plan_id, :metric_id, :period, :value

      def metric_name
        Metric.load_name(service_id, metric_id)
      end

      def validate(usage)
        usage_value = usage[period]
        usage_value &&= usage_value[metric_id].to_i
        usage_value <= value
      end

      class << self
        include Memoizer::Decorator

        def load_all(service_id, plan_id)
          metric_ids = Metric.load_all_ids(service_id)
          return [] if metric_ids.nil? || metric_ids.empty?

          pairs = pairs_of_metric_id_and_period(metric_ids)

          keys = keys_for_pairs_of_metric_id_and_period(service_id, plan_id, pairs)
          values = storage.mget(*keys)

          pairs.each_with_index.map do |(metric_id, period), index|
            value = values[index]
            value && new(service_id: service_id,
                         plan_id: plan_id,
                         metric_id: metric_id,
                         period: period,
                         value: value.to_i)
          end.compact
        end
        memoize :load_all

        def load_value(service_id, plan_id, metric_id, period)
          raw_value = storage.get(key(service_id, plan_id, metric_id, period))
          raw_value && raw_value.to_i
        end

        def save(attributes)
          PERIODS.select { |period| attributes[period] }.each do |period|
            storage.set(key(attributes[:service_id],
                            attributes[:plan_id],
                            attributes[:metric_id],
                            period),
                        attributes[period])
          end
          clear_cache(attributes[:service_id], attributes[:plan_id])
          Service.incr_version(attributes[:service_id])
        end

        def delete(service_id, plan_id, metric_id, period)
          storage.del(key(service_id, plan_id, metric_id, period))
          clear_cache(service_id, plan_id)
          Service.incr_version(service_id)
        end

        private

        def key(service_id, plan_id, metric_id, period)
          encode_key("usage_limit/service_id:#{service_id}/plan_id:#{plan_id}" +
                     "/metric_id:#{metric_id}/#{period}")
        end

        def pairs_of_metric_id_and_period(metric_ids)
          pairs = []
          metric_ids.each do |metric_id|
            PERIODS.each do |period|
              pairs << [metric_id, period]
            end
          end

          pairs
        end

        def keys_for_pairs_of_metric_id_and_period(service_id, plan_id, pairs)
          key_prefix = "usage_limit/service_id:#{service_id}/plan_id:#{plan_id}"
          pairs.map do |metric_id, period|
            encode_key("#{key_prefix}/metric_id:#{metric_id}/#{period}")
          end
        end

        def clear_cache(service_id, plan_id)
          Memoizer.clear(Memoizer.build_key(self, :load_all, service_id, plan_id))
        end
      end

    end
  end
end
