module ThreeScale
  module Backend
    class Contract < Core::Contract
      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end

      def live?
        state.nil? || state == :live
      end
    end
  end
end
