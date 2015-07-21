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
        # Returns false in case of invalid params (negative TTL
        # or invalid token).
        #
        def create(service_id, app_id, token, user_id, ttl = nil)
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

          user_id = nil if user_id && user_id.empty?

          storage.pipelined do
            storage.sadd(users_set_key(service_id, app_id), user_id) if user_id
            storage.sadd(token_set_key(service_id, app_id, user_id), token)
          end

          true
        end

        def delete(service_id, user_id, token)
          key = token_key(service_id, token)
          app_id = storage.get key
          return :notfound if app_id.nil?
          token_set = token_set_key(service_id, app_id, user_id)

          if delete_token_unchecked(token_set, token, key)
            update_users(token_set, service_id, app_id, user_id)
            :deleted
          else
            :forbidden
          end
        end

        def all_by_service_and_app(service_id, app_id, user_id)
          user_id = nil if user_id && user_id.empty?
          set_key = token_set_key(service_id, app_id, user_id)
          tokens = storage.smembers(set_key)

          if user_id.nil?
            # get tokens from all the users
            users, user_tokens = get_user_tokens_for service_id, app_id
            # prepend user_tokens to tokens for use below
            users << nil
            user_tokens << tokens
            tokens = user_tokens
          else
            users = [user_id]
            tokens = [tokens]
          end

          results = []
          users.zip(tokens) do |user, tok|
            keys = tok.map { |t| token_key(service_id, t) }
            applications = keys.empty? ? [] : storage.mget(keys)
            tok.zip(applications, keys).map do |token, app, key|
              if app.nil?
                # remove expired tokens
                token_set = token_set_key(service_id, app_id, user)
                if delete_token_unchecked(token_set, token, key)
                  update_users(token_set, service_id, app, user)
                end
              else
                ttl = storage.ttl(key)
                results << OAuthAccessToken.new(token, ttl, user)
              end
            end
          end

          results
        end

        def get_app_id(service_id, token, user_id)
          app_id = storage.get(token_key(service_id, token))
          return nil unless app_id
          if storage.sismember(token_set_key(service_id, app_id, user_id), token)
            # found, everyone is happy :)
            app_id
          else
            # :/ if a user was specified and the token not found there, try
            #    the global list of tokens for this app, else return nil
            if user_id && storage.sismember(token_set_key(service_id, app_id, nil), token)
              app_id
            end
          end
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

        # delete a token without extra checks, just using the parameters
        def delete_token_unchecked(token_set, token, token_key)
          storage.del token_key if storage.srem(token_set, token)
        end

        # delete the user from the list if this was its last token
        # we check for an empty user token set (non-existing)
        def update_users(token_set, service_id, app_id, user_id)
          if user_id && !user_id.empty? && !storage.exists(token_set)
            storage.srem(users_set_key(service_id, app_id), user_id)
          end
        end

        def get_user_tokens_for(service_id, app_id)
          users_set = users_set_key(service_id, app_id)
          users = storage.smembers(users_set)
          user_tokens = storage.pipelined do
            users.each do |u|
              storage.smembers(token_set_key(service_id, app_id, u))
            end
          end
          [users, user_tokens]
        end

      end
    end
  end
end
