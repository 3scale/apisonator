module ThreeScale
  module Backend
    class Application
      module Sets
        include ThreeScale::Backend::HasSet
        has_set :referrer_filters
        has_set :keys
      end

      include Sets
      include Storable

      attr_accessor :service_id, :id, :state, :plan_id, :plan_name,
        :user_required, :redirect_url, :version

      def to_hash
        {
          service_id: service_id,
          id: id,
          state: state,
          plan_id: plan_id,
          plan_name: plan_name,
          user_required: user_required,
          redirect_url: redirect_url,
          version: version
        }
      end

      def update(attributes)
        attributes.each do |attr, val|
          public_send("#{attr}=", val)
        end
        self
      end

      class << self
        include Memoizer::Decorator

        def load(service_id, id)
          return nil unless service_id and id
          values = storage.mget(storage_key(service_id, id, :state),
                                storage_key(service_id, id, :plan_id),
                                storage_key(service_id, id, :plan_name),
                                storage_key(service_id, id, :user_required),
                                storage_key(service_id, id, :redirect_url),
                                storage_key(service_id, id, :version))
          state, plan_id, plan_name, user_required, redirect_url, vv = values

          # save a network call by just checking state here for existence
          return nil unless state

          ## the default value is false
          user_required = user_required.to_i > 0
          self.incr_version(service_id, id) unless vv

          new(service_id: service_id,
              id: id,
              state: state.to_sym,
              plan_id: plan_id,
              plan_name: plan_name,
              user_required: user_required,
              redirect_url: redirect_url,
              version: self.get_version(service_id, id))
        end
        memoize :load

        def load!(service_id, app_id)
          load(service_id, app_id) or raise ApplicationNotFound, app_id
        end
        memoize :load!

        def load_id_by_key(service_id, key)
          storage.get(id_by_key_storage_key(service_id, key))
        end
        memoize :load_id_by_key

        def save_id_by_key(service_id, key, id)
          raise ApplicationHasInconsistentData.new(id, key) if [service_id, id, key].any?(&:blank?)
          storage.set(id_by_key_storage_key(service_id, key), id).tap do
            Memoizer.memoize(Memoizer.build_key(self, :load_id_by_key, service_id, key), id)
          end
        end

        def delete_id_by_key(service_id, key)
          storage.del(id_by_key_storage_key(service_id, key)).tap do
            Memoizer.clear(Memoizer.build_key(self, :load_id_by_key, service_id, key))
          end
        end

        def load_by_id_or_user_key!(service_id, app_id, user_key)
          with_app_id_from_params service_id, app_id, user_key do |appid|
            load service_id, appid
          end
        end

        def extract_id!(service_id, app_id, user_key, access_token)
          with_app_id_from_params service_id, app_id, user_key, access_token do |appid|
            exists? service_id, appid and appid
          end
        end

        def exists?(service_id, id)
          storage.exists(storage_key(service_id, id, :state))
        end
        memoize :exists?

        def get_version(service_id, id)
          storage.get(storage_key(service_id, id, :version))
        end

        def incr_version(service_id, id)
          storage.incrby(storage_key(service_id, id, :version), 1)
        end

        def delete(service_id, id)
          raise ApplicationNotFound, id unless exists?(service_id, id)
          delete_data service_id, id
          clear_cache service_id, id
        end

        def delete_data(service_id, id)
          delete_set(service_id, id)
          delete_attributes(service_id, id)
        end

        def clear_cache(service_id, id)
          keys = Memoizer.build_keys_for_class(self,
                    load: [service_id, id],
                    load!: [service_id, id],
                    exists?: [service_id, id])
          Memoizer.clear keys
        end

        def applications_set_key(service_id)
          encode_key("service_id:#{service_id}/applications")
        end

        def save(attributes)
          application = new(attributes)
          application.save
          application
        end

        def storage_key(service_id, id, attribute)
          encode_key("application/service_id:#{service_id}/id:#{id}/#{attribute}")
        end

        private

        def id_by_key_storage_key(service_id, key)
          encode_key("application/service_id:#{service_id}/key:#{key}/id")
        end

        def delete_set(service_id, id)
          storage.srem(applications_set_key(service_id), id)
        end

        def delete_attributes(service_id, id)
          storage.del(storage_key(service_id, id, :state))
          storage.del(storage_key(service_id, id, :plan_id))
          storage.del(storage_key(service_id, id, :plan_name))
          storage.del(storage_key(service_id, id, :user_required))
          storage.del(storage_key(service_id, id, :redirect_url))
          storage.del(storage_key(service_id, id, :version))
        end

        def with_app_id_from_params(service_id, app_id, user_key, access_token = nil)
          if app_id
            raise AuthenticationError unless user_key.nil?
          elsif user_key
            app_id = load_id_by_key(service_id, user_key)
            raise UserKeyInvalid, user_key if app_id.nil?
          elsif access_token
            app_id = OAuthAccessTokenStorage.get_app_id service_id, access_token
            raise AccessTokenInvalid, access_token if app_id.nil?
          else
            raise ApplicationNotFound
          end

          yield app_id or raise ApplicationNotFound, app_id
        end

      end

      def user_required?
        @user_required
      end

      def save
        persist_attributes
        persist_set

        self.version = self.class.incr_version(service_id, id).to_s
        self.class.clear_cache(service_id, id)

        Memoizer.memoize(Memoizer.build_key(self.class, :exists?, service_id, id), state)
      end

      def storage_key(attribute)
        self.class.storage_key(service_id, id, attribute)
      end

      def applications_set_key(service_id)
        self.class.applications_set_key(service_id)
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

      # Creates new application key and adds it to the list of keys of this application.
      # If +value+ is nil, generates new random key, otherwise uses the given value as
      # the new key.
      def create_key(value = nil)
        Application.incr_version(service_id,id)
        super(value || SecureRandom.hex(16))
      end

      def delete_key(value)
        Application.incr_version(service_id,id)
        super(value)
      end

      def create_referrer_filter(value)
        raise ReferrerFilterInvalid, "referrer filter can't be blank" if value.blank?
        Application.incr_version(service_id,id)
        super(value)
      end

      def delete_referrer_filter(value)
        Application.incr_version(service_id,id)
        super(value)
      end

      def active?
        state == :active
      end

      private

      def persist_attributes
        storage.set(storage_key(:state), state.to_s) if state
        storage.set(storage_key(:plan_id), plan_id) if plan_id
        storage.set(storage_key(:plan_name), plan_name) if plan_name
        storage.set(storage_key(:user_required), user_required? ? 1 : 0)
        storage.set(storage_key(:redirect_url), redirect_url) if redirect_url
      end

      def persist_set
        storage.sadd(applications_set_key(service_id), id)
      end
    end
  end
end
