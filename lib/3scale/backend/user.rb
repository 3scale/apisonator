module ThreeScale
  module Backend
    class User < Core::User

      #def self.load!(service, username)
      #  load(service, username)
      #end
      
      def self.load_or_create!(service, user_id)
        key = "User.load_or_create!-#{service.id}-#{user_id}"
        Memoizer.memoize_block(key) do 
          super(service, user_id)
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

    end
  end
end
