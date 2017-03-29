module ThreeScale
  module Backend
    class CubertServiceManagementUseCase
      class << self
        include StorageHelpers
        include Configurable

        def global_enable
          storage.set global_lock_key, 1
        end

        def global_disable
          storage.del global_lock_key
        end

        def clean_cubert_redis_keys
          storage.del global_lock_key
          storage.smembers(all_bucket_keys_key).each { |s| storage.del s }
          storage.del all_bucket_keys_key
        end

        def enable_service(service_id, new_bucket)
          raise BucketMissing if new_bucket.blank?

          bucket_key = bucket_id_key service_id
          storage.set bucket_key, new_bucket
          storage.sadd all_bucket_keys_key, bucket_key
        end

        def disable_service(service_id)
          old_bucket = bucket service_id

          storage.del(bucket_id_key(service_id))
          storage.srem all_bucket_keys_key, old_bucket
        end

        def enabled?(service_id)
          globally_enabled, service_bucket = storage.pipelined do
            storage.get global_lock_key
            storage.get(bucket_id_key service_id)
          end
          globally_enabled.to_i == 1 && service_bucket
        end

        def bucket(service_id)
          storage.get(bucket_id_key(service_id))
        end

        def connection
          Cubert::Client::Connection.new(configuration.cubert.host)
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
