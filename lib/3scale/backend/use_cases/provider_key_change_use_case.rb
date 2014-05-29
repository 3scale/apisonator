module ThreeScale
  module Backend
    class ProviderKeyChangeUseCase

      def initialize(old_key, new_key)
        @old_key = old_key
        @new_key = new_key

        validate_input
      end

      def process
        default_service_id = Service.default_id(@old_key)

        service_ids.each do |service_id|
          storage.set Service.storage_key(service_id, :provider_key), @new_key
          storage.sadd Service.storage_key_by_provider(@new_key, :ids), service_id
          storage.incr Service.storage_key(service_id, :version)
        end

        storage.set Service.storage_key_by_provider(@new_key, :id), default_service_id

        storage.del Service.storage_key_by_provider(@old_key, :id)
        storage.del Service.storage_key_by_provider(@old_key, :ids)

        clear_cache service_ids
      end

      private

      def service_ids
        @service_ids ||= Service.list(@old_key)
      end

      def validate_input
        raise InvalidProviderKeys if [@old_key, @new_key].
          any?{ |key| key.nil? || key.empty? } || @old_key == @new_key

        raise ProviderKeyExists, @new_key if Service.list(@new_key).size != 0

        raise ProviderKeyNotFound, @old_key if service_ids.size == 0
      end

      def storage
        Service.storage
      end

      def clear_cache(service_ids)
        keys = provider_cache_keys(@old_key) +
          provider_cache_keys(@new_key) +
          service_ids.map{ |id| "Service.load_by_id-#{id}"} +
          authentication_cache_keys(@old_key, service_ids) +
          authentication_cache_keys(@new_key, service_ids)

        Memoizer.clear keys
      end

      def provider_cache_keys(key)
        [
          "Service.default_id-#{key}",
          "Service.load-#{key}",
          "Service.list-#{key}",
        ]
      end

      def authentication_cache_keys(key, service_ids)
        service_ids.map{ |id| "Service.authenticate_service_id-#{id}-#{key}" }
      end

    end
  end
end
