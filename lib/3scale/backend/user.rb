module ThreeScale
  module Backend
    module CoreUser
      def self.included(base)
        base.include InstanceMethods
        base.extend ClassMethods
      end

      module InstanceMethods
        def save
          service = Service.load_by_id(service_id)

          save_attributes

          ServiceUserManagementUseCase.new(service, username).add.tap do
            self.class.clear_cache(service_id, username)
          end
        end

        def active?
          state == :active
        end

        def key
          self.class.key(service_id, username)
        end

        def storage_key
          self.class.storage_key(service_id, username, attribute)
        end

        private

        def save_attributes
          storage.hset key, "state", state.to_s if state
          storage.hset key, "plan_id", plan_id if plan_id
          storage.hset key, "plan_name", plan_name if plan_name
          storage.hset key, "username", username if username
          storage.hset key, "service_id", service_id if service_id
          storage.hincrby key, "version", 1
        end
      end

      module ClassMethods
        def load(service_id, username)
          key = self.key(service_id, username)

          values = storage.hmget(key, 'state', 'plan_id', 'plan_name', 'version')
          state, plan_id, plan_name, vv = values

          user = nil
          unless state.nil?
            user = new(service_id: service_id,
                       username: username,
                       state: state.to_sym,
                       plan_id: plan_id,
                       plan_name: plan_name)

            incr_version(service_id, username) if vv.nil?
          end

          return user
        end

        def load_or_create!(service, username)
          user = load(service.id, username)

          if user.nil?
            # the user does not exist yet, we need to create it for the case of
            # the open loop
            if service.user_registration_required?
              raise ServiceRequiresRegisteredUser, service.id
            else
              raise ServiceRequiresDefaultUserPlan, service.id if service.default_user_plan_id.nil? ||
                service.default_user_plan_name.nil?
            end

            user = new(service_id: service.id,
                       username: username,
                       state: :active,
                       plan_id: service.default_user_plan_id,
                       plan_name: service.default_user_plan_name)
            user.save
          end

          return user
        end

        def save!(attributes)
          raise UserRequiresUsername if attributes[:username].nil?
          raise UserRequiresServiceId if attributes[:service_id].nil?
          service = Service.load_by_id(attributes[:service_id])
          raise UserRequiresValidService if service.nil?
          attributes[:plan_id] ||= service.default_user_plan_id
          attributes[:plan_name] ||= service.default_user_plan_name
          raise UserRequiresDefinedPlan if attributes[:plan_id].nil? || attributes[:plan_name].nil?
          attributes[:state] = "active" if attributes[:state].nil?
          user = new(attributes)
          user.save
          return user
        end

        def get_version(service_id, username)
          storage.hget(self.key(service_id, username), 'version')
        end

        def incr_version(service_id, username)
          storage.hincrby(self.key(service_id, username), 'version', 1)
        end

        def delete!(service_id, username)
          service = Service.load_by_id(service_id)
          raise UserRequiresValidService if service.nil?
          ServiceUserManagementUseCase.new(service, username).delete
          clear_cache(service_id, username)
          storage.del(self.key(service_id, username))
        end

        def key(service_id, username)
          "service:#{service_id}/user:#{username}"
        end

        def storage_key(service_id, username, attribute)
          "service:#{service_id}/user:#{username}/#{attribute}"
        end

        def clear_cache(service_id, user_id)
          key = Memoizer.build_key(self, :load_or_create!, service_id, user_id)
          Memoizer.clear key
        end

      end
    end

    class User
      include CoreUser
      include Core::Storable

      attr_accessor :service_id, :username, :state, :plan_id, :plan_name
      attr_writer :version

      def to_hash
        {
          service_id: service_id,
          username: username,
          state: state,
          plan_id: plan_id,
          plan_name: plan_name,
        }
      end

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

      private

      # Username is used as a unique user ID
      def user_id
        username
      end

    end
  end
end
