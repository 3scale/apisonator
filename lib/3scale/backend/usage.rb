module ThreeScale
  module Backend
    class Usage
      class << self
        def user_usage(user, timestamp)
          usage user do |metric_id, period|
            Stats::Keys.user_usage_value_key(
                user.service_id, user.username, metric_id, period.new(timestamp))
          end
        end

        def application_usage(application, timestamp)
          usage application do |metric_id, period|
            Stats::Keys.usage_value_key(
                application.service_id, application.id, metric_id, period.new(timestamp))
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

        def usage(obj)
          pairs = metric_period_pairs obj.usage_limits
          return {} if pairs.empty?

          keys = pairs.map(&Proc.new)
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
