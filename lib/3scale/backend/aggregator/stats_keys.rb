module ThreeScale
  module Backend
    module Aggregator
      module StatsKeys
        module_function

        extend Core::StorageKeyHelpers

        def bucket_with_service_key(bucket, service)
          "#{service}:#{bucket}"
        end

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
      end
    end
  end
end
