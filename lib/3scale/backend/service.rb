module ThreeScale
  module Backend
    class Service < Core::Service
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

        def load_id!(provider_key)
          key = "Service.load_id!-#{provider_key}"
          Memoizer.memoize_block(key) do
            load_id(provider_key) or raise ProviderKeyInvalid, provider_key
          end
        end

        def load(provider_key)
          key = "Service.load-#{provider_key}"
          Memoizer.memoize_block(key) do
            super(provider_key)
          end
        end

        def load!(provider_key)
          key = "Service.load!-#{provider_key}"
          Memoizer.memoize_block(key) do
            load(provider_key) or raise ProviderKeyInvalid, provider_key
          end
        end

        def load_by_id!(service_id)
          key = "Service.load_by_id!-#{service_id}"
          Memoizer.memoize_block(key) do
            load_by_id(service_id) or raise ServiceIdInvalid, service_id
          end
        end

        def load_by_id(service_id)
          key = "Service.load_by_id-#{service_id}"
          Memoizer.memoize_block(key) do
            next nil if (id = service_id.to_s).nil?

            values = get_service(id)
            referrer_filters_required, backend_version, user_registration_required,
              default_user_plan_id, default_user_plan_name, provider_key, vv = values

            next nil if provider_key.nil?
            increment_attr(id, :version) if vv.nil?

            referrer_filters_required = referrer_filters_required.to_i > 0
            user_registration_required = massage_user_registration_required(
              user_registration_required)

            default_service_id = load_id(provider_key)

            new(
              :provider_key              => provider_key,
              :id                        => id,
              :referrer_filters_required => referrer_filters_required,
              :user_registration_required => user_registration_required,
              :backend_version           => backend_version,
              :default_user_plan_id      => default_user_plan_id,
              :default_user_plan_name    => default_user_plan_name,
              :default_service           => default_service_id == id,
              :version                   => get_attr(id, :version)
            )
          end
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
            storage.smembers(id_storage_key_set(provider_key)) || []
          end
        end

        private

        # nil => true, 1 => true, '1' => true, 0 => false, '0' => false
        def massage_user_registration_required(value)
          value.nil? ? true : value.to_i > 0
        end

        def increment_attr(id, attribute)
          storage.incrby(storage_key(id, attribute), 1)
        end

        def get_attr(id, attribute)
          storage.get(storage_key(id, attribute))
        end

      end
    end
  end
end
