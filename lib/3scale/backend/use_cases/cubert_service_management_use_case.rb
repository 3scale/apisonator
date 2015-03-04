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
          storage.del enabled_services_key
          storage.del all_bucket_keys_key
        end

        def global_lock_key
          'cubert_request_log_storage_enabled'
        end

        def enabled_services_key
          'cubert_enabled_services'
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

      def enable_service
        unless storage.get bucket_id_key
          storage.set bucket_id_key, self.class.connection.create_bucket
          storage.sadd self.class.all_bucket_keys_key, bucket_id_key
        end
        storage.sadd self.class.enabled_services_key, @service_id
      end

      def disable_service
        storage.srem self.class.enabled_services_key, @service_id
      end

      def bucket
        storage.get bucket_id_key
      end

      def enabled?
        global_enable, service_enable = storage.pipelined do
          storage.get(self.class.global_lock_key)
          storage.sismember(self.class.enabled_services_key, @service_id)
        end
        global_enable.to_i == 1 && service_enable
      end

      def bucket_id_key
        "cubert_request_log_bucket_service_#{@service_id}"
      end

    end
  end
end
