module ThreeScale
  module Backend
    class UsageLimit < Core::UsageLimit
      def validate(usage)
        usage_value = usage[period]
        usage_value &&= usage_value[metric_id].to_i

        raise LimitsExceeded if usage_value > value
        true
      end
    end
  end
end
