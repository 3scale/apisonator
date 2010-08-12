module ThreeScale
  module Backend
    class Application < Core::Application
      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end

      def active?
        state == :active
      end
    end
  end
end
