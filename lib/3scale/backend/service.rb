module ThreeScale
  module Backend
    class Service
      include Core::Storable

      attr_accessor :provider_key, :id, :backend_version,
        :default_user_plan_id, :default_user_plan_name
      attr_writer :referrer_filters_required, :user_registration_required,
        :version, :default_service

      class << self
        # Returns true if a given service belongs to the provider with
        # that key without loading the whole object.
        #
        def authenticate_service_id(service_id, provider_key)
          key = "Service.authenticate_service_id-#{service_id}-#{provider_key}"
          Memoizer.memoize_block(key) do
            provider_key == storage.get(storage_key(service_id, 'provider_key'))
          end
        end

        def load_id(provider_key)
          key = "Service.load_id-#{provider_key}"
          Memoizer.memoize_block(key) do
            storage.get(storage_key_by_provider(provider_key, :id))
          end
        end

        def load_id!(provider_key)
          load_id(provider_key) or raise ProviderKeyInvalid, provider_key
        end

        def load(provider_key)
          key = "Service.load-#{provider_key}"
          Memoizer.memoize_block(key) do
            load_by_id load_id(provider_key)
          end
        end

        def load!(provider_key)
          load(provider_key) or raise ProviderKeyInvalid, provider_key
        end

        def load_by_id(service_id)
          key = "Service.load_by_id-#{service_id}"
          Memoizer.memoize_block(key) do
            next nil if service_id.nil?

            referrer_filters_required, backend_version, user_registration_required,
              default_user_plan_id, default_user_plan_name, provider_key, vv =
                get_service(id = service_id.to_s)

            next nil if provider_key.nil?
            increment_attr(id, :version) if vv.nil?

            referrer_filters_required = referrer_filters_required.to_i > 0
            user_registration_required = massage_get_user_registration_required(
              user_registration_required)
            default_service_id = load_id(provider_key)

            new(
              :provider_key               => provider_key,
              :id                         => id,
              :referrer_filters_required  => referrer_filters_required,
              :user_registration_required => user_registration_required,
              :backend_version            => backend_version,
              :default_user_plan_id       => default_user_plan_id,
              :default_user_plan_name     => default_user_plan_name,
              :default_service            => default_service_id == id,
              :version                    => get_attr(id, :version)
            )
          end
        end

        def load_by_id!(service_id)
          load_by_id(service_id) or raise ServiceIdInvalid, service_id
        end

        def get_service(id)
          storage.mget(
            storage_key(id, :referrer_filters_required),
            storage_key(id, :backend_version),
            storage_key(id, :user_registration_required),
            storage_key(id, :default_user_plan_id),
            storage_key(id, :default_user_plan_name),
            storage_key(id, :provider_key),
            storage_key(id, :version)
          )
        end

        def list(provider_key)
          key = "Service.list-#{provider_key}"
          Memoizer.memoize_block(key) do
            storage.smembers(storage_key_by_provider(provider_key, :ids)) || []
          end
        end

        def save!(attributes = {})
          massage_set_user_registration_required attributes

          new(attributes).save!
        end

        def storage_key(id, attribute)
          encode_key("service/id:#{id}/#{attribute}")
        end

        def storage_key_by_provider(provider_key, attribute)
          encode_key("service/provider_key:#{provider_key}/#{attribute}")
        end

        private

        # nil => true, 1 => true, '1' => true, 0 => false, '0' => false
        def massage_get_user_registration_required(value)
          value.nil? ? true : value.to_i > 0
        end

        def massage_set_user_registration_required(attributes)
          if attributes[:user_registration_required].nil?
            val = storage.get(storage_key(attributes[:id], :user_registration_required))
            attributes[:user_registration_required] =
              (!val.nil? && val.to_i == 0) ? false : true
          end
        end

        def increment_attr(id, attribute)
          storage.incrby(storage_key(id, attribute), 1)
        end

        def get_attr(id, attribute)
          storage.get(storage_key(id, attribute))
        end
      end

      def default_service?
        @default_service
      end

      def referrer_filters_required?
        @referrer_filters_required
      end

      def user_registration_required?
        @user_registration_required
      end

      def save!
        validate_user_registration_required
        set_as_default_if_needed
        persist
        clean_cache

        self
      end

      private

      def storage_key(attribute)
        self.class.storage_key id, attribute
      end

      def storage_key_by_provider(attribute)
        self.class.storage_key_by_provider provider_key, attribute
      end

      def clean_cache
        keys = [
          "Service.authenticate_service_id-#{id}-#{provider_key}",
          "Service.load_id-#{provider_key}",
          "Service.load-#{provider_key}",
          "Service.load_by_id-#{id}",
          "Service.list-#{provider_key}"
        ]
        Memoizer.clear keys
      end

      def validate_user_registration_required
        @user_registration_required = true if @user_registration_required.nil?

        if !user_registration_required? &&
          (default_user_plan_id.nil? || default_user_plan_name.nil?)
          raise ServiceRequiresDefaultUserPlan
        end
      end

      def set_as_default_if_needed
        default_service_id = self.class.load_id(provider_key)
        @default_service = default_service_id.nil?
      end

      def persist
        storage.multi do
          # Set as default service
          storage.set(storage_key_by_provider(:id), id) if default_service?

          # Add to Services list for provider_key
          storage.sadd(storage_key_by_provider(:ids), id)

          storage.set(storage_key(:referrer_filters_required),
            referrer_filters_required? ? 1 : 0)

          storage.set(storage_key(:user_registration_required),
            user_registration_required? ? 1 : 0)
          storage.set(storage_key(:default_user_plan_id), default_user_plan_id
            ) unless default_user_plan_id.nil?
          storage.set(storage_key(:default_user_plan_name), default_user_plan_name
            ) unless default_user_plan_name.nil?

          storage.set(storage_key(:backend_version), backend_version) if backend_version
          storage.set(storage_key(:provider_key), provider_key)
          storage.incrby(storage_key(:version), 1)
          storage.sadd(encode_key("services_set"), id)
          storage.sadd(encode_key("provider_keys_set"), provider_key)
        end
      end

    end
  end
end
