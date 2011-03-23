
module ThreeScale
  module Backend
    class User 
      include ThreeScale::Core::Storable

      attr_accessor :service_id
      attr_accessor :username
      attr_accessor :state
      attr_accessor :plan_id
      attr_accessor :plan_name
      
      def self.load!(service, username)
        
        key = self.storage_key(service.id, username)

        values = storage.hmget(key,"state","plan_id","plan_name")
        state, plan_id, plan_name = values

        user = nil

        if state.nil? 
          ## the user does not exist

          return nil if service.user_registration_required?
          ## the user did not exist and we need to create it

          user = User.new(:service_id => service.id,
                     :username   => username,
                     :state      => :active.to_sym,
                     :plan_id    => service.default_user_plan_id,
                     :plan_name  => service.default_user_plan_name) 

          user.save

        else 
       
          user = User.new(:service_id => service.id,
                        :username   => username,
                        :state      => state.to_sym,
                        :plan_id    => plan_id,
                        :plan_name  => plan_name)

        end

        return user

      end


      def self.save(attributes)
        user = new(attributes)
        user.save
        user
      end

      def save  
        key = storage_key
        storage.hset(key,"state", state.to_s) if state
        storage.hset(key,"plan_id", plan_id)     if plan_id
        storage.hset(key,"plan_name", plan_name) if plan_name
        storage.hset(key,"username", username) if username
        storage.hset(key,"service_id", service_id) if service_id
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

      def active?
        state == :active
      end

      def storage_key
          self.class.storage_key(service_id,username)
      end

      def self.storage_key(service_id, username)
         "service:#{service_id}/user:#{username}"
      end



    end
  end
end
