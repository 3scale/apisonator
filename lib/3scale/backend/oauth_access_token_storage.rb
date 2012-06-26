module ThreeScale
  module Backend

    class OAuthAccessToken
      attr_reader :token
      attr_accessor :ttl

      def initialize(token, ttl)
        @token = token
        @ttl = ttl
      end
    end

    module OAuthAccessTokenStorage
      extend Backend::StorageHelpers


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
        keys = tokens.map { |t| token_key(service_id, t) }
        applications = storage.mget(*keys)
        set_key = token_set_key(service_id, app_id)

        result = tokens.map.with_index do |token,i|
          if applications[i].nil?
            # remove expired tokens from the set
            storage.srem(set_key, token)
            nil
          else
            ttl = storage.ttl(token_key(service_id, app_id))
            OAuthAccessToken.new(token, ttl)
          end
        end

        result.compact
      end
      
      def self.get_app_id(service_id, token)
        app_id = storage.get(token_key(service_id,token))
        storage.srem(token_set_key(service_id, app_id), token) if app_id.nil?
        app_id
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
