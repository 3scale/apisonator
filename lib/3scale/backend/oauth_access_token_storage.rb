module ThreeScale
  module Backend

    class OAuthAccessToken
      attr_reader :token, :user_id
      attr_accessor :ttl

      def initialize(token, ttl, user_id = nil)
        @token = token
        @ttl = ttl
        @user_id = user_id
      end
    end

    module OAuthAccessTokenStorage
      extend Backend::StorageHelpers

      MAXIMUM_TOKEN_SIZE = 1024

      class << self

        # Creates OAuth Access Token association with the Application.
        #
        # Returns false in case of invalid invalid params (negative TTL
        # or invalid token).
        #
        def create(service_id, app_id, token, ttl = nil)
          ##return false unless token =~ /\A(\w|-)+\Z/
          ##anything can go on an access token
          return false if token.nil? || token.empty? || !token.is_a?(String) || token.size > MAXIMUM_TOKEN_SIZE

          key = token_key(service_id, token)

          raise AccessTokenAlreadyExists.new(token) unless storage.get(key).nil?

          if ttl.nil?
            storage.set(key, app_id)
          else
            ttl = ttl.to_i
            return false if ttl <= 0

            storage.setex(key, ttl, app_id)
          end

          storage.sadd(token_set_key(service_id, app_id), token)
          true
        end

        def delete(service_id, token)
          key = token_key(service_id, token)
          app_id = storage.get key
          storage.pipelined do
            storage.del key
            storage.srem(token_set_key(service_id, app_id), token)
          end
        end

        def all_by_service_and_app(service_id, app_id)
          tokens = storage.smembers(token_set_key(service_id, app_id))
          keys = tokens.map { |t| token_key(service_id, t) }
          applications = keys.empty? ? [] : storage.mget(keys)
          set_key = token_set_key(service_id, app_id)

          result = tokens.map.with_index do |token,i|
            if applications[i].nil?
              # remove expired tokens from the set
              storage.srem(set_key, token)
              nil
            else
              ttl = storage.ttl(keys[i])
              OAuthAccessToken.new(token, ttl)
            end
          end

          result.compact
        end

        def get_app_id(service_id, token)
          storage.get(token_key(service_id, token))
        end

        private

        def token_key(service_id, token)
          "oauth_access_tokens/service:#{service_id}/#{token}"
        end

        def token_set_key(service_id, app_id, user_id)
          key = "oauth_access_tokens/service:#{service_id}/app:#{app_id}/"
          key << "user:#{user_id}/" if user_id
          key
        end

        def users_set_key(service_id, app_id)
          token_set_key(service_id, app_id, nil) << "users/"
        end

      end
    end
  end
end
