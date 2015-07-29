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

          # build the storage command so that we can pipeline everything cleanly
          command = :set
          args = [key]

          if ttl
            ttl = ttl.to_i
            return false if ttl <= 0
            command = :setex
            args << ttl
          end

          args << if user_id.blank?
                    user_id = nil
                    app_id
                  else
                    "user:#{user_id}/#{app_id}"
                  end

          token_set = token_set_key(service_id, app_id, user_id)
          users_set = users_set_key(service_id, app_id) if user_id

          storage.pipelined do
            storage.send(command, *args)
            storage.sadd(token_set, token)
            storage.sadd(users_set, user_id) if user_id
          end

          # Now make sure everything ended up there
          #
          # Note that we have a sharding proxy and pipelines can't be guaranteed
          # to behave like transactions, since we might have one non-working
          # shard. Instead of relying on proxy-specific responses, we just check
          # that the data we should have in the store is really there.
          results = storage.pipelined do
            storage.get(key)
            storage.sismember(token_set, token)
            storage.sismember(users_set, user_id) if user_id
          end

          results.shift == args.last && results.all? { |x| x == true } ||
            raise(AccessTokenStorageError.new(token))
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

          users, grouped_tokens = get_grouped_tokens_for service_id, app_id, user_id

          results = []
          users.zip(grouped_tokens) do |user, tokens|
            keys = tokens.map { |t| token_key(service_id, t) }
            applications = keys.empty? ? [] : storage.mget(keys)
            tokens.zip(applications, keys).map do |token, app, key|
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
          get_app_for_key(token_key(service_id, token), user_id)
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

        def get_grouped_user_tokens_for(service_id, app_id)
          users_set = users_set_key(service_id, app_id)
          users = storage.smembers(users_set)
          user_grouped_tokens = storage.pipelined do
            users.each do |u|
              storage.smembers(token_set_key(service_id, app_id, u))
            end
          end
          [users, user_grouped_tokens]
        end

        # returns [users, tokens grouped by user respectively]
        def get_grouped_tokens_for(service_id, app_id, user_id)
          set_key = token_set_key(service_id, app_id, user_id)
          grouped_tokens = storage.smembers(set_key)

          if user_id.nil?
            # get tokens from all the users
            users, user_grouped_tokens = get_grouped_user_tokens_for service_id, app_id
            # prepend user_tokens to tokens for use below
            users << nil
            user_grouped_tokens << grouped_tokens
            grouped_tokens = user_grouped_tokens
          else
            users = [user_id]
            grouped_tokens = [grouped_tokens]
          end

          [users, grouped_tokens]
        end

        # returns the app_id read from a storage key's value,
        # checking the user id if present
        def get_app_from_value(value, user_id = nil)
          if value.nil? || user_id.nil?
            value
          else
            user_id_magic = "user:#{user_id}/"
            if value.start_with? user_id_magic
              value[user_id_magic.size..-1]
            else
              nil
            end
          end
        end

        def get_apps_for_keys(keys, user_id)
          return [] if keys.empty?
          storage.mget(keys).map do |value|
            get_app_from_value value, user_id
          end
        end

        def get_app_for_key(key, user_id)
          get_app_from_value(storage.get(key), user_id)
        end
      end
    end
  end
end
