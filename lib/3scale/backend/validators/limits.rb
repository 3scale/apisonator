module ThreeScale
  module Backend
    module Validators
      class Limits < Base

        def apply
          valid_limits? ? succeed! : fail!(LimitsExceeded.new)
        end

        private

        def process(values, raw_usage)
          if raw_usage
            metrics = Metric.load_all(status.service_id)
            usage   = metrics.process_usage(raw_usage, status.flat_usage)
            values  = filter_metrics(values, usage.keys)
            values  = increment_or_set(values, usage)
          end

          values
        end

        def valid_limits?
          processed_values = process(status.values, params[:usage])
          status.application.usage_limits.all? do |limit|
            limit.validate(processed_values)
          end
        end

        def filter_metrics(values, metric_ids)
          values.inject({}) do |memo, (period, usage)|
            memo[period] = slice_hash(usage, metric_ids)
            memo
          end
        end

        def increment_or_set(values, usage)
          usage.inject(values) do |memo, (metric_id, value)|
            memo.keys.each do |period|
              memo[period][metric_id] = Usage.get_from value, memo[period][metric_id].to_i
            end

            memo
          end
        end

        # TODO: Move this to extensions/hash.rb
        def slice_hash(hash, keys)
          keys.inject({}) do |memo, key|
            memo[key] = hash[key] if hash.has_key?(key)
            memo
          end
        end
      end
    end
  end
end
