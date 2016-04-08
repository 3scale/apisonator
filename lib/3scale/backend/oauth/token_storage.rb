module ThreeScale
  module Backend
    module OAuth
      class Token
        module Storage
          MAXIMUM_TOKEN_SIZE = 1024
          private_constant :MAXIMUM_TOKEN_SIZE
          TOKEN_MAX_REDIS_SLICE_SIZE = 500
          private_constant :TOKEN_MAX_REDIS_SLICE_SIZE

          Error = Class.new StandardError
          InconsistencyError = Class.new Error

          class << self
            include Backend::Logging
            include Backend::StorageHelpers

            def create(token, service_id, app_id, user_id, ttl = nil)
              return false if token.nil? || token.empty? || !token.is_a?(String) || token.size > MAXIMUM_TOKEN_SIZE

              key = Key.for token, service_id
              raise AccessTokenAlreadyExists.new(token) unless storage.get(key).nil?

              value = Value.for(app_id, user_id)
              token_set = Key::Set.for(service_id, app_id)

              if store_token token, token_set, key, value, ttl
                ensure_stored! token, token_set, key, value
              end
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
                  Airbrake.notify(InconsistencyError.new("Found OAuth token " \
                    "#{token} for service #{service_id} and app #{app_id} as " \
                    "key but not in set!"))
                end
              end

              val
            end

            # Get a token's associated [app_id, user_id]
            def get_credentials(token, service_id)
              Value.from(storage.get(Key.for(token, service_id)))
            end

            # This is used to list tokens by service, app and possibly user.
            def all_by_service_and_app(service_id, app_id, user_id = nil)
              token_set = Key::Set.for(service_id, app_id)
              iter = tokens_n_values_flat(token_set, service_id)
              if user_id
                iter = iter.select do |(_token, _key, value, _ttl)|
                  _app_id, uid = Value.from value
                  uid == user_id
                end
              end
              iter.map do |(token, _key, value, ttl)|
                if user_id
                  Token.new token, service_id, app_id, user_id, ttl
                else
                  Token.from_value token, service_id, value, ttl
                end
              end.force
            end

            # This removes tokens whose user_id match. Note that if user_id is
            # nil it WILL NOT remove tokens associated to specific users!
            #
            # Use remove_all_tokens to remove all tokens of a service and app.
            def remove_tokens(service_id, app_id, user_id)
              remove_tokens_by service_id, app_id do |_t, _k, v, _ttl|
                user_id == Value.from(v).last
              end
            end

            # MUST... PRESS... BIG... RED... BRIGHT... BUTTON...
            def remove_all_tokens(service_id, app_id)
              remove_tokens_by service_id, app_id
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
                return
              end

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
            def store_token(token, token_set, key, value, ttl)
              # build the storage command so that we can pipeline everything cleanly
              command = :set
              args = [key]

              if ttl
                ttl = ttl.to_i
                return false if ttl <= 0
                command = :setex
                args << ttl
              end

              args << value

              storage.pipelined do
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
          end
        end
      end
    end
  end
end
