module ThreeScale
  module Backend
    class ServiceToken

      module KeyHelpers
        def key(service_token, service_id)
          encode_key("service_token/token:#{service_token}/service_id:#{service_id}")
        end
      end

      include KeyHelpers
      extend KeyHelpers
      include Storable

      ValidationError = Class.new(ThreeScale::Backend::Invalid)

      class InvalidServiceToken < ValidationError
        def initialize
          super('Service token cannot be blank'.freeze)
        end
      end

      class InvalidServiceId < ValidationError
        def initialize
          super('Service ID cannot be blank'.freeze)
        end
      end

      # We want to use a hash in Redis because in the future we might have
      # several fields related to permissions and roles.
      # For now we do not need any of those fields, but we need to define at
      # least one to be able to create a hash, even if we are not going to use
      # it.
      PERMISSIONS_KEY_FIELD = 'permissions'.freeze
      private_constant :PERMISSIONS_KEY_FIELD

      class << self
        include Memoizer::Decorator

        def save(service_token, service_id)
          validate_pairs([{ service_token: service_token, service_id: service_id }])
          storage.hset(key(service_token, service_id), PERMISSIONS_KEY_FIELD, ''.freeze)
        end

        # Saves a collection of (service_token, service_id) pairs only if all
        # the pairs contain valid data, meaning that there are no null or empty
        # strings.
        def save_pairs(token_id_pairs)
          validate_pairs(token_id_pairs)

          token_id_pairs.each do |pair|
            unchecked_save(pair[:service_token], pair[:service_id])
          end
        end

        def delete(service_token, service_id)
          res = storage.del(key(service_token, service_id))
          clear_cache(service_token, service_id)
          res
        end

        def exists?(service_token, service_id)
          storage.exists?(key(service_token, service_id))
        end
        memoize :exists?

        private

        def validate_pairs(token_id_pairs)
          invalid_token = token_id_pairs.any? do |pair|
            pair[:service_token].nil? || pair[:service_token].empty?
          end
          raise InvalidServiceToken if invalid_token

          invalid_service_id = token_id_pairs.any? do |pair|
            pair[:service_id].nil? || pair[:service_id].to_s.empty?
          end
          raise InvalidServiceId if invalid_service_id
        end

        def unchecked_save(service_token, service_id)
          storage.hset(key(service_token, service_id), PERMISSIONS_KEY_FIELD, ''.freeze)
        end

        def storage
          Storage.instance
        end

        def clear_cache(service_token, service_id)
          Memoizer.clear(Memoizer.build_key(self, :exists?, service_token, service_id))
        end

      end

    end
  end
end
