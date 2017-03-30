module ThreeScale
  module Backend
    class CubertServiceManagementUseCase
      class << self
        include StorageHelpers

        def global_enable
          storage.set global_lock_key, 1
        end

        def global_disable
          storage.del global_lock_key
        end

        def clean_cubert_redis_keys
          storage.del global_lock_key
          storage.del all_bucket_keys_key
        end

        def enable_service(service_id)
          storage.sadd all_bucket_keys_key, bucket_id_key(service_id)
        end

        def disable_service(service_id)
          storage.srem all_bucket_keys_key, bucket_id_key(service_id)
        end

        def enabled?(service_id)
          globally_enabled, service_bucket = storage.pipelined do
            storage.get global_lock_key
            storage.sismember(all_bucket_keys_key, bucket_id_key(service_id))
          end
          globally_enabled.to_i == 1 && service_bucket
        end

        def globally_enabled?
          storage.get(global_lock_key).to_i == 1
        end

        def service_enabled?(service_id)
          storage.sismember(all_bucket_keys_key, bucket_id_key(service_id))
        end

        private

        def global_lock_key
          'cubert_request_log_storage_enabled'
        end

        def all_bucket_keys_key
          'cubert_bucket_keys'
        end

        def bucket_id_key(service_id)
          "cubert_request_log_bucket_service_#{service_id}"
        end
      end
    end
  end
end
