module ThreeScale
  module Backend
    module OAuth
      class Token
        module Storage
          include Configurable

          # Default token size is 4K - 512 (to allow for some metadata)
          MAXIMUM_TOKEN_SIZE = configuration.oauth.max_token_size || 3584
          private_constant :MAXIMUM_TOKEN_SIZE
          TOKEN_MAX_REDIS_SLICE_SIZE = 500
          private_constant :TOKEN_MAX_REDIS_SLICE_SIZE
          TOKEN_TTL_DEFAULT = 86400
          private_constant :TOKEN_TTL_DEFAULT
          TOKEN_TTL_PERMANENT = 0
          private_constant :TOKEN_TTL_PERMANENT

          Error = Class.new StandardError
          InconsistencyError = Class.new Error

          class << self
            include Backend::Logging
            include Backend::StorageHelpers

            def create(token, service_id, app_id, user_id, ttl = nil)
              raise AccessTokenFormatInvalid if token.nil? || token.empty? ||
                !token.is_a?(String) || token.bytesize > MAXIMUM_TOKEN_SIZE

              # raises if TTL is invalid
              ttl = sanitized_ttl ttl

              key = Key.for token, service_id
              raise AccessTokenAlreadyExists.new(token) unless storage.get(key).nil?

              value = Value.for(app_id, user_id)
              token_set = Key::Set.for(service_id, app_id)

              store_token token, token_set, key, value, ttl
              ensure_stored! token, token_set, key, value
            end

            # Deletes a token
            #
            # Returns the associated [app_id, user_id] or nil
            #
            def delete(token, service_id)
              key = Key.for token, service_id
              val = storage.get key
              if val
                val = Value.from val
                app_id = val.first
                token_set = Key::Set.for(service_id, app_id)

                existed, * = remove_a_token token_set, token, key

                unless existed
                  logger.notify(InconsistencyError.new("Found OAuth token " \
                    "#{token} for service #{service_id} and app #{app_id} as " \
                    "key but not in set!"))
                end
              end

              val
            end

            # Get a token's associated [app_id, user_id]
            def get_credentials(token, service_id)
              ids = Value.from(storage.get(Key.for(token, service_id)))
              raise AccessTokenInvalid.new token if ids.first.nil?
              ids
            end

            # This is used to list tokens by service, app and possibly user.
            #
            # Note: this deletes tokens that have not been found from the set of
            # tokens for the given app - those have to be expired tokens.
            def all_by_service_and_app(service_id, app_id, user_id = nil)
              token_set = Key::Set.for(service_id, app_id)
              deltokens = []
              tokens_n_values_flat(token_set, service_id)
                .select do |(token, _key, value, _ttl)|
                  app_id, uid = Value.from value
                  if app_id.nil?
                    deltokens << token
                    false
                  else
                    !user_id || uid == user_id
                  end
                end
                .map do |(token, _key, value, ttl)|
                  if user_id
                    Token.new token, service_id, app_id, user_id, ttl
                  else
                    Token.from_value token, service_id, value, ttl
                  end
                end
                .force.tap do
                  # delete expired tokens (nil values) from token set
                  deltokens.each_slice(TOKEN_MAX_REDIS_SLICE_SIZE) do |delgrp|
                    storage.srem token_set, delgrp
                  end
                end
            end

            # Remove tokens by app_id and optionally user_id.
            #
            # If user_id is nil or unspecified, this will remove all app tokens
            #
            # Triggered by Application deletion.
            #
            # TODO: we could expose the ability to delete all tokens for a given
            # user_id, but we are currently not doing that.
            #
            def remove_tokens(service_id, app_id, user_id = nil)
              filter = lambda do |_t, _k, v, _ttl|
                user_id == Value.from(v).last
              end if user_id
              remove_tokens_by service_id, app_id, &filter
            end


            private

            # Remove all tokens or only those selected by a block
            #
            # I thought of leaving this one public, but remove_*_tokens removed
            # my use cases for the time being.
            def remove_tokens_by(service_id, app_id, &blk)
              token_set = Key::Set.for(service_id, app_id)

              # No block? Just remove everything and smile!
              if blk.nil?
                remove_whole_token_set(token_set, service_id)
              else
                remove_token_set_by(token_set, service_id, &blk)
              end
            end

            def remove_token_set_by(token_set, service_id, &blk)
              # Get tokens. Filter them. Group them into manageable groups.
              # Extract tokens and keys into separate arrays, one for each.
              # Remove tokens from token set (they are keys in a set) and token
              # keys themselves.
              tokens_n_values_flat(token_set, service_id, false)
              .select(&blk)
              .each_slice(TOKEN_MAX_REDIS_SLICE_SIZE)
              .inject([[], []]) do |acc, groups|
                groups.each do |token, key, _value|
                  acc[0] << token
                  acc[1] << key
                end
                acc
              end
              .each_slice(2)
              .inject([]) do |acc, (tokens, keys)|
                storage.pipelined do
                  if tokens && !tokens.empty?
                    storage.srem token_set, tokens
                    acc.concat tokens
                  end
                  storage.del keys if keys && !keys.empty?
                end
                acc
              end
            end

            def remove_a_token(token_set, token, key)
              storage.pipelined do
                storage.srem token_set, token
                storage.del key
              end
            end

            def remove_whole_token_set(token_set, service_id)
              _token_groups, key_groups = tokens_n_keys(token_set, service_id)
              storage.pipelined do
                storage.del token_set
                # remove all tokens for this app
                key_groups.each do |keys|
                  storage.del keys
                end
              end
            end

            # TODO: provide a SSCAN interface with lazy enums because SMEMBERS
            # is prone to DoSing and timeouts
            def tokens_from(token_set)
              # It is important that we make this a lazy enumerator. The
              # laziness is maintained until some enumerator forces execution or
              # the caller calls 'to_a' or 'force', whichever happens first.
              storage.smembers(token_set).lazy
            end

            def tokens_n_keys(token_set, service_id)
              token_groups = tokens_from(token_set).each_slice(TOKEN_MAX_REDIS_SLICE_SIZE)
              key_groups = token_groups.map do |tokens|
                tokens.map do |token|
                  Key.for token, service_id
                end
              end
              # Note: this is returning two lazy enumerators
              [token_groups, key_groups]
            end

            # Provides grouped data (as sourced from the lazy iterators) which
            # matches respectively in each array position, ie. 1st group of data
            # contains a group of tokens, keys and values with ttls, and
            # position N of the tokens group has key in position N of the keys
            # group, and so on.
            #
            # [[[token group], [key group], [value_with_ttls_group]], ...]
            #
            def tokens_n_values_groups(token_set, service_id, with_ttls)
              token_groups, key_groups = tokens_n_keys(token_set, service_id)
              value_ttl_groups = key_groups.map do |keys|
                # pipelining will create an array with the results of commands
                res = storage.pipelined do
                  storage.mget(keys)
                  if with_ttls
                    keys.map do |key|
                      storage.ttl key
                    end
                  end
                end
                # [mget array, 0..n ttls] => [mget array, ttls array]
                [res.shift, res]
              end
              token_groups.zip(key_groups, value_ttl_groups)
            end

            # Zips the data provided by tokens_n_values_groups so that you stop
            # looking at indexes in the respective arrays and instead have:
            #
            # [group 0, ..., group N] where each group is made of:
            #   [[token 0, key 0, value 0, ttl 0], ..., [token N, key N, value
            #   N, ttl N]]
            #
            def tokens_n_values_zipped_groups(token_set, service_id, with_ttls = true)
              tokens_n_values_groups(token_set,
                                     service_id,
                                     with_ttls).map do |tokens, keys, (values, ttls)|
                tokens.zip keys, values, ttls
              end
            end

            # Flattens the data provided by tokens_n_values_zipped_groups so
            # that you have a transparent iterator with all needed data and can
            # stop worrying about streaming groups of elements.
            #
            def tokens_n_values_flat(token_set, service_id, with_ttls = true)
              tokens_n_values_zipped_groups(token_set,
                                            service_id,
                                            with_ttls).flat_map do |groups|
                groups.map do |token, key, value, ttl|
                  [token, key, value, ttl]
                end
              end
            end

            # Store the specified token in Redis
            #
            # TTL specified in seconds.
            # A TTL of 0 stores a permanent token
            def store_token(token, token_set, key, value, ttl)
              # build the storage command so that we can pipeline everything cleanly
              command = :set
              args = [key]

              if !permanent_ttl? ttl
                command = :setex
                args << ttl
              end

              args << value

              # pipelined will return nil if it is embedded into another
              # pipeline(which would be an error at this point) or if shutting
              # down and a connection error happens. Both things being abnormal
              # means we should just raise a storage error.
              raise AccessTokenStorageError, token unless storage.pipelined do
                storage.send(command, *args)
                storage.sadd(token_set, token)
              end
            end


            # Make sure everything ended up there
            #
            # TODO: review and possibly reimplement trying to leave it
            # consistent as much as possible.
            #
            # Note that we have a sharding proxy and pipelines can't be guaranteed
            # to behave like transactions, since we might have one non-working
            # shard. Instead of relying on proxy-specific responses, we just check
            # that the data we should have in the store is really there.
            def ensure_stored!(token, token_set, key, value)
              results = storage.pipelined do
                storage.get(key)
                storage.sismember(token_set, token)
              end

              results.last && results.first == value ||
                raise(AccessTokenStorageError, token)
            end

	    # Validation for the TTL value
	    #
	    # 0 is accepted (understood as permanent token)
	    # Negative values are not accepted
	    # Integer(ttl) validation is required (if input is nil, default applies)
	    def sanitized_ttl(ttl)
              ttl = begin
                      Integer(ttl)
                    rescue TypeError
                      # ttl is nil
                      TOKEN_TTL_DEFAULT
                    rescue
                      # NaN
                      -1
                    end
              raise AccessTokenInvalidTTL if ttl < 0

	      ttl
            end

	    # Check whether a TTL has the magic value for a permanent token
	    def permanent_ttl?(ttl)
              ttl == TOKEN_TTL_PERMANENT
	    end
          end
        end
      end
    end
  end
end
