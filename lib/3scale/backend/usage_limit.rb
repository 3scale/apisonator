module ThreeScale
  module Backend
    class UsageLimit < Core::UsageLimit
      def validate(usage)
        usage_value = usage[period]
        usage_value &&= usage_value[metric_id].to_i

        usage_value <= value
      end
    end
  end
end
