module ThreeScale
  module Backend
    class User < Core::User

      def self.load_or_create!(service, user_id)
        key = Memoizer.build_key(self, :load_or_create!, service.id, user_id)
        Memoizer.memoize_block(key) do
          super service, user_id
        end
      end

      def metric_names
        @metric_names ||= {}
      end

      def metric_names=(hash)
        @metric_names = hash
      end

      def metric_name(metric_id)
        metric_names[metric_id] ||= Metric.load_name(service_id, metric_id)
      end

      def usage_limits
        @usage_limits ||= UsageLimit.load_all(service_id, plan_id)
      end

      # Copy-pasted from Core
      def save
        service = Service.load_by_id(service_id)
        ServiceUserManagementUseCase.new(service, username).add

        storage.hset key, "state", state.to_s if state
        storage.hset key, "plan_id", plan_id if plan_id
        storage.hset key, "plan_name", plan_name if plan_name
        storage.hset key, "username", username if username
        storage.hset key, "service_id", service_id if service_id
        storage.hincrby key, "version", 1

      end

      private

      # Username is used as a unique user ID
      def user_id
        username
      end

    end
  end
end
