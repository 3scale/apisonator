module ThreeScale
  module Backend
    module Validators
      class Limits < Base
        def apply
          values = process(status.values, params[:usage]) unless status.application.nil?
          user_values = process(status.user_values, params[:usage]) unless status.user.nil? 

          check_user = true
          check_app = true

          check_app = status.application.usage_limits.all? { |limit| limit.validate(values) } unless status.application.nil?
          check_user =  status.user.usage_limits.all? { |limit| limit.validate(user_values) } unless status.user.nil?

          if check_user && check_app
            succeed!
          else
            fail!(LimitsExceeded.new)
          end
        end

        private

        def process(values, raw_usage)
          if raw_usage
            metrics = Metric.load_all(status.service.id)
            usage   = metrics.process_usage(raw_usage)

            values = filter_metrics(values, usage.keys)
            values = increment_or_set(values, usage)
            values
          else
            values
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
              val = ThreeScale::Backend::Aggregator::get_value_of_set_if_exists(value)
              if val.nil?
                memo[period][metric_id] ||= 0
                memo[period][metric_id] += value.to_i
              else
                memo[period][metric_id] = val
              end
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
