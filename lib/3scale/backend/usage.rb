module ThreeScale
  module Backend
    class Usage
      class << self

        # Side-effect: user.metric_names is overwritten with all the names of
        # metrics for which there is a usage limit defined that applies to
        # user.
        def user_usage(user, timestamp)
          usage user do |metric_id, period|
            Stats::Keys.user_usage_value_key(
                user.service_id, user.username, metric_id, period.new(timestamp))
          end
        end

        # Side-effect: application.metric_names is overwritten with all the
        # names of metrics for which there is a usage limit defined that
        # applies to application.
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
          pairs, metric_ids = get_pairs_and_metric_ids obj.usage_limits
          return {} if pairs.empty?

          # preloading metric names
          obj.metric_names = Metric.load_all_names(obj.service_id, metric_ids)
          keys = pairs.map(&Proc.new)
          values = {}
          pairs.zip(storage.mget(keys)) do |(metric_id, period), value|
            values[period] ||= {}
            values[period][metric_id] = value.to_i
          end
          values
        end

        def get_pairs_and_metric_ids(usage_limits)
          pairs = []

          metric_ids = usage_limits.map do |usage_limit|
            m_id = usage_limit.metric_id
            pairs << [m_id, usage_limit.period]
            m_id
          end

          [pairs, metric_ids]
        end

        def storage
          Storage.instance
        end
      end
    end
  end
end
