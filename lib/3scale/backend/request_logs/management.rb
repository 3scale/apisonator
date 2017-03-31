module ThreeScale
  module Backend
    module RequestLogs
      class Management
        GLOBAL_LOCK_KEY = 'cubert_request_log_storage_enabled'.freeze
        private_constant :GLOBAL_LOCK_KEY

        SERVICES_SET_KEY = 'cubert_bucket_keys'.freeze
        private_constant :SERVICES_SET_KEY

        class << self
          include StorageHelpers

          def global_enable
            storage.set GLOBAL_LOCK_KEY, 1
          end

          def global_disable
            storage.del GLOBAL_LOCK_KEY
          end

          def clean_cubert_redis_keys
            storage.del GLOBAL_LOCK_KEY
            storage.del SERVICES_SET_KEY
          end

          def enable_service(service_id)
            storage.sadd SERVICES_SET_KEY, bucket_id_key(service_id)
          end

          def disable_service(service_id)
            storage.srem SERVICES_SET_KEY, bucket_id_key(service_id)
          end

          def enabled?(service_id)
            globally_enabled, service_bucket = storage.pipelined do
              storage.get GLOBAL_LOCK_KEY
              storage.sismember(SERVICES_SET_KEY, bucket_id_key(service_id))
            end
            globally_enabled.to_i == 1 && service_bucket
          end

          def globally_enabled?
            storage.get(GLOBAL_LOCK_KEY).to_i == 1
          end

          # NOTE: This is meant to be used by the Rake task alone, as the global
          # lock IS NOT TAKEN INTO ACCOUNT!
          def service_enabled?(service_id)
            storage.sismember(SERVICES_SET_KEY, bucket_id_key(service_id))
          end

          private

          def bucket_id_key(service_id)
            "cubert_request_log_bucket_service_#{service_id}"
          end
        end
      end
    end
  end
end
