module ThreeScale
  module Backend

    module OAuthAccessToken
      attr_reader :token, :ttl, :app_id

      def initialize(token, app_id, ttl)
        @token
      end
    end

    module OAuthAccessTokenStorage
      extend Backend::StorageHelpers

      # one day
      DEFAULT_TTL = 24 * 3600

      def self.create(service_id, app_id, token)
        storage.set(token_key(service_id, token), app_id)
        storage.sadd(token_set_key(service_id, app_id), token)
      end

      def self.delete(service_id, token)
        storage.del(token_key(service_id, token))
        storage.srem(token_set_key(service_id, app_id), token)
      end

      def self.all_by_service_and_app(service_id, app_id)
        tokens = storage.smembers(token_set_key(service_id, app_id))
        ttls = storage.pipelined do
          keys.each do |key|
            storage.ttl(key)
          end
        end

        tokens.map { |token| OAuthAccessToken.new(token, app_id, ttl) }
      end

      private

      def self.token_key(service_id, token)
        "oauth_access_tokens/service:#{service_id}/#{token}"
      end

      def self.token_set_key(service_id, app_id)
        "oauth_access_tokens/service:#{$service_id}/app:$app_id/"
       end

    end
  end
end
