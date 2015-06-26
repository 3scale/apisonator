module ThreeScale
  module Backend
    class CubertServiceManagementUseCase
      include StorageHelpers
      extend StorageHelpers
      include Configurable

      class << self
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

        def global_lock_key
          'cubert_request_log_storage_enabled'
        end

        def all_bucket_keys_key
          'cubert_bucket_keys'
        end

        def connection
          @connection ||= Cubert::Client::Connection.new(configuration.cubert.host)
        end
      end

      def initialize service_id
        @service_id = service_id
      end

      def enable_service new_bucket = nil
        new_bucket ||= self.class.connection.create_bucket

        storage.set bucket_id_key, new_bucket
        storage.sadd self.class.all_bucket_keys_key, bucket_id_key
      end

      def disable_service
        old_bucket = bucket

        storage.del bucket_id_key
        storage.srem self.class.all_bucket_keys_key, old_bucket
      end

      def bucket
        storage.get bucket_id_key
      end

      def enabled?
        global_enable, service_bucket = storage.pipelined do
          storage.get(self.class.global_lock_key)
          bucket
        end
        global_enable.to_i == 1 && service_bucket
      end

      def bucket_id_key
        "cubert_request_log_bucket_service_#{@service_id}"
      end

    end
  end
end
