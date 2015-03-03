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
          storage.smembers(enabled_services_key).each do
            |s| new(s).disable_service
          end
          storage.del enabled_services_key
        end

        def global_lock_key
          'cubert_request_log_storage_enabled'
        end

        def enabled_services_key
          'cubert_enabled_services'
        end

        def connection
          @connection ||= Cubert::Client::Connection.new(configuration.cubert.host)
        end
      end

      def initialize service_id
        @service_id = service_id
      end

      def enable_service
        storage.set bucket_id_key, self.class.connection.create_bucket
        storage.sadd self.class.enabled_services_key, @service_id
      end

      def disable_service
        storage.del bucket_id_key
        storage.srem self.class.enabled_services_key, @service_id
      end

      def bucket
        storage.get bucket_id_key
      end

      def enabled?
        storage.get(self.class.global_lock_key).to_i == 1 &&
          storage.sismember(self.class.enabled_services_key, @service_id)
      end

      private

      def bucket_id_key
        "cubert_request_log_bucket_service_#{@service_id}"
      end

    end
  end
end
