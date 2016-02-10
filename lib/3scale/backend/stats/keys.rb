module ThreeScale
  module Backend
    module Stats
      module Keys
        module_function

        extend Backend::StorageKeyHelpers

        # @note The { ... } is the key tag. See redis docs for more info
        # about key tags.
        def service_key_prefix(service_id)
          "stats/{service:#{service_id}}"
        end

        # @note For backwards compatibility, the key is called cinstance.
        # It will be eventually renamed to application.
        def application_key_prefix(prefix, application_id)
          "#{prefix}/cinstance:#{application_id}"
        end

        def applications_key_prefix(prefix)
          "#{prefix}/cinstances"
        end

        # @note For backwards compatibility, the key is called uinstance.
        # It will be eventually renamed to user.
        def user_key_prefix(prefix, user_id)
          "#{prefix}/uinstance:#{user_id}"
        end

        def metric_key_prefix(prefix, metric_id)
          "#{prefix}/metric:#{metric_id}"
        end

        def response_code_key_prefix(prefix, response_code)
          "#{prefix}/response_code:#{response_code}"
        end

        def usage_value_key(application, metric_id, period, time)
          service_key = service_key_prefix(application.service_id)
          app_key     = application_key_prefix(service_key, application.id)
          metric_key  = metric_key_prefix(app_key, metric_id)

          encode_key(counter_key(metric_key, period, time))
        end

        def user_usage_value_key(user, metric_id, period, time)
          service_key = service_key_prefix(user.service_id)
          user_key    = user_key_prefix(service_key, user.username)
          metric_key  = metric_key_prefix(user_key, metric_id)

          encode_key(counter_key(metric_key, period, time))
        end

        def counter_key(prefix, granularity, timestamp)
          key = "#{prefix}/#{granularity}"
          if granularity != :eternity
            key += ":#{timestamp.beginning_of_cycle(granularity).to_compact_s}"
          end

          key
        end

        # We want all the buckets to go to the same Redis shard.
        # The reason is that SUNION support in Twemproxy requires that the
        # supplied keys hash to the same server.
        # We are already using a hash tag in the Twemproxy config file: "{}".
        # For that reason, if we specify a key that contains something like
        # "{stats_bucket}", we can be sure that all of them will be in the same
        # shard.
        def changed_keys_bucket_key(bucket)
          "{stats_bucket}:#{bucket}"
        end

        def changed_keys_key
          "keys_changed_set"
        end

        def transaction_keys(transaction, item, value)
          service_key     = service_key_prefix(transaction.service_id)
          application_key = application_key_prefix(service_key,
                                                   transaction.application_id)

          method = "#{item}_key_prefix".to_sym

          keys = {
            service:     public_send(method, service_key, value),
            application: public_send(method, application_key, value),
          }

          if transaction.user_id
            user_key = user_key_prefix(service_key, transaction.user_id)
            keys[:user] = public_send(method, user_key, value)
          end

          keys
        end

      end
    end
  end
end
