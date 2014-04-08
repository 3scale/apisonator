module ThreeScale
  module Backend
    class Service
      include Core::Storable
      include Backend::Helpers
      extend Backend::Helpers

      ATTRIBUTES = %w(referrer_filters_required backend_version
        user_registration_required default_user_plan_id default_user_plan_name
        provider_key version)

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

        def default_id(provider_key)
          key = "Service.default_id-#{provider_key}"
          Memoizer.memoize_block(key) do
            storage.get(storage_key_by_provider(provider_key, :id))
          end
        end

        def default_id!(provider_key)
          default_id(provider_key) or raise ProviderKeyInvalid, provider_key
        end

        def load(provider_key)
          key = "Service.load-#{provider_key}"
          Memoizer.memoize_block(key) do
            load_by_id default_id(provider_key)
          end
        end

        def load!(provider_key)
          load(provider_key) or raise ProviderKeyInvalid, provider_key
        end

        def load_by_id(service_id)
          key = "Service.load_by_id-#{service_id}"
          Memoizer.memoize_block(key) do
            next if service_id.nil?

            service_attrs = get_service(id = service_id.to_s)
            massage_service_attrs id, service_attrs

            next if service_attrs['provider_key'].nil?

            new(service_attrs.merge(id: id,
              default_service: default_service?(service_attrs['provider_key'], id)
            ))
          end
        end

        def load_by_id!(service_id)
          load_by_id(service_id) or raise ServiceIdInvalid, service_id
        end

        def delete_by_id(service_id, options = {})
          service = load_by_id(service_id)
          if service.default_service? && !options[:force]
            raise ServiceIsDefaultService, service.id
          end

          service.delete_data
          service.clear_cache
        end

        def get_service(id)
          keys = ATTRIBUTES.map { |attr| storage_key(id, attr) }
          values = storage.mget(keys)

          result = {}
          ATTRIBUTES.each_with_index do |key, idx|
            result[key] = values[idx]
          end
          result
        end

        # TODO: Is it used?
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

        def massage_service_attrs(id, service_attrs)
          service_attrs['referrer_filters_required'] = int_to_bool(
            service_attrs['referrer_filters_required'])
          service_attrs['user_registration_required'] = massage_get_user_registration_required(
            service_attrs['user_registration_required'])
          service_attrs['version'] = massage_version(id, service_attrs['version'])

          service_attrs
        end

        # nil => true, 1 => true, '1' => true, 0 => false, '0' => false
        def massage_get_user_registration_required(value)
          value.nil? ? true : int_to_bool(value)
        end

        def massage_set_user_registration_required(attributes)
          if attributes[:user_registration_required].nil?
            val = storage.get(storage_key(attributes[:id], :user_registration_required))
            attributes[:user_registration_required] =
              (!val.nil? && val.to_i == 0) ? false : true
          end
        end

        def massage_version(id, vv)
          vv || storage.incr(storage_key(id, :version))
        end

        def get_attr(id, attribute)
          storage.get(storage_key(id, attribute))
        end

        def default_service?(provider_key, id)
          default_id(provider_key) == id.to_s
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
        clear_cache

        self
      end

      def clear_cache
        keys = [
          "Service.authenticate_service_id-#{id}-#{provider_key}",
          "Service.default_id-#{provider_key}",
          "Service.load-#{provider_key}",
          "Service.load_by_id-#{id}",
          "Service.list-#{provider_key}"
        ]
        Memoizer.clear keys
      end

      def storage_key(attribute)
        self.class.storage_key id, attribute
      end

      def delete_data
        storage.multi do
          delete_attributes
          delete_from_lists
        end
      end

      def bump_version
        storage.incr storage_key(:version)
      end

      def to_hash
        {
          id: id,
          provider_key: provider_key,
          backend_version: backend_version,
          referrer_filters_required: referrer_filters_required?,
          user_registration_required: user_registration_required?,
          default_user_plan_id: default_user_plan_id,
          default_user_plan_name: default_user_plan_name,
        }
      end

      private

      def delete_attributes
        storage.del ATTRIBUTES.map{ |attr| storage_key(attr) }
        storage.del storage_key(:user_set)
        storage.del storage_key_by_provider(:id) if default_service?
      end

      def delete_from_lists
        storage.srem storage_key_by_provider(:ids), id
        storage.srem encode_key('services_set'), id
        storage.del storage_key_by_provider(:ids) if default_service?
      end

      def storage_key_by_provider(attribute)
        self.class.storage_key_by_provider provider_key, attribute
      end

      def validate_user_registration_required
        @user_registration_required = true if @user_registration_required.nil?

        if !user_registration_required? &&
          (default_user_plan_id.nil? || default_user_plan_name.nil?)
          raise ServiceRequiresDefaultUserPlan
        end
      end

      def set_as_default_if_needed
        if @default_service.nil?
          default_service_id = self.class.default_id(provider_key)
          @default_service = default_service_id.nil?
        end
      end

      def persist
        old_default_id = self.class.default_id(provider_key) if default_service?

        storage.multi do
          persist_default old_default_id
          persist_attributes
          persist_sets

          bump_version
        end
      end

      def persist_default(old_default_id)
        if default_service? && old_default_id != id
          storage.set storage_key_by_provider(:id), id
          storage.incr self.class.storage_key(old_default_id, :version)
        end
      end

      def persist_attributes
        persist_attribute :referrer_filters_required,
          bool_to_int(referrer_filters_required?)
        persist_attribute :user_registration_required,
          bool_to_int(user_registration_required?)
        persist_attribute :default_user_plan_id, default_user_plan_id, true
        persist_attribute :default_user_plan_name, default_user_plan_name, true
        persist_attribute :backend_version, backend_version, true
        persist_attribute :provider_key, provider_key
      end

      def persist_attribute(attribute, value, ignore_nils = false)
        storage.set storage_key(attribute), value unless ignore_nils && value.nil?
      end

      def persist_sets
        storage.sadd storage_key_by_provider(:ids), id
        storage.sadd encode_key("services_set"), id
        storage.sadd encode_key("provider_keys_set"), provider_key
      end

    end
  end
end
