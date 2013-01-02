module ThreeScale
  module Backend
    class Service < Core::Service

      # Returns true if a given service belongs to the provider with
      # that key without loading the whole object.
      #
      def self.authenticate_service_id(service_id, provider_key)
        provider_key == storage.get(storage_key(service_id, 'provider_key'))
      end

      def self.load_id!(provider_key)
        key = "Service.load_id!-#{provider_key}"
        
        ser = begin
          if !Memoizer.memoized?(key)
            Memoizer.memoize(key, load_id(provider_key))
          else
            Memoizer.get(key)
          end
        end
        
        ser or raise ProviderKeyInvalid, provider_key
      end

      def self.load!(provider_key)
        key = "Service.load!-#{provider_key}"
        
        ser = begin
          if !Memoizer.memoized?(key)
            Memoizer.memoize(key, load(provider_key))
          else
            Memoizer.get(key)
          end
        end
        
        ser or raise ProviderKeyInvalid, provider_key
      end

      def self.load_by_id!(service_id)
        key = "Service.load_by_id!-#{service_id}"
        
        ser = begin
          if !Memoizer.memoized?(key)
            Memoizer.memoize(key, load_by_id(service_id))
          else
            Memoizer.get(key)
          end
        end
        
        ser or raise ServiceIdInvalid, service_id
      end

    end
  end
end
