module ThreeScale
  module Backend
    class Contract < Core::Contract
      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end
    end
  end
end
