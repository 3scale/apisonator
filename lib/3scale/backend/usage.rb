module ThreeScale
  module Backend
    class Usage
      class << self
        def application_usage(application, timestamp)
          usage(application, timestamp) do |metric_id, instance_period|
            Stats::Keys.application_usage_value_key(
                application.service_id, application.id, metric_id, instance_period)
          end
        end

        def is_set?(usage_str)
          usage_str && usage_str[0] == '#'.freeze
        end

        def get_from(usage_str, current_value = 0)
          if is_set? usage_str
            usage_str[1..-1].to_i
          else
            # Note: this relies on the fact that NilClass#to_i returns 0
            # and String#to_i returns 0 on non-numeric contents.
            current_value + usage_str.to_i
          end
        end

        private

        def usage(obj, timestamp)
          # The timestamp does not change, so we can generate all the
          # instantiated periods just once.
          # This is important. Without this, the code can generate many instance
          # periods and it ends up consuming a significant part of the total CPU
          # time.
          instance_periods = Period::instance_periods_for_ts(timestamp)

          pairs = metric_period_pairs obj.usage_limits
          return {} if pairs.empty?

          keys = pairs.map do |(metric_id, period)|
            yield metric_id, instance_periods[period]
          end

          values = {}
          pairs.zip(storage.mget(keys)) do |(metric_id, period), value|
            values[period] ||= {}
            values[period][metric_id] = value.to_i
          end
          values
        end

        def metric_period_pairs(usage_limits)
          usage_limits.map do |usage_limit|
            [usage_limit.metric_id, usage_limit.period]
          end
        end

        def storage
          Storage.instance
        end
      end
    end
  end
end
