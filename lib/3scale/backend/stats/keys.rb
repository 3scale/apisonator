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

        def metric_key_prefix(prefix, metric_id)
          "#{prefix}/metric:#{metric_id}"
        end

        def response_code_key_prefix(prefix, response_code)
          "#{prefix}/response_code:#{response_code}"
        end

        def service_usage_value_key(service_id, metric_id, period)
          service_key = service_key_prefix(service_id)
          metric_key  = metric_key_prefix(service_key, metric_id)

          encode_key(counter_key(metric_key, period))
        end

        def application_usage_value_key(service_id, app_id, metric_id, period)
          service_key = service_key_prefix(service_id)
          app_key     = application_key_prefix(service_key, app_id)
          metric_key  = metric_key_prefix(app_key, metric_id)

          encode_key(counter_key(metric_key, period))
        end

        def service_response_code_value_key(service_id, response_code, period)
          service_key        = service_key_prefix(service_id)
          response_code_key  = response_code_key_prefix(service_key, response_code)

          encode_key(counter_key(response_code_key, period))
        end

        def application_response_code_value_key(service_id, app_id, response_code, period)
          service_key        = service_key_prefix(service_id)
          app_key            = application_key_prefix(service_key, app_id)
          response_code_key  = response_code_key_prefix(app_key, response_code)

          encode_key(counter_key(response_code_key, period))
        end

        def counter_key(prefix, period)
          granularity = period.granularity
          key = "#{prefix}/#{granularity}"
          if granularity.to_sym != :eternity
            key += ":#{period.start.to_compact_s}"
          end

          key
        end

        def set_of_apps_with_traffic(service_id)
          Stats::Keys.applications_key_prefix(
            Stats::Keys.service_key_prefix(service_id)
          )
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

          {
            service:     public_send(method, service_key, value),
            application: public_send(method, application_key, value),
          }
        end

      end
    end
  end
end
