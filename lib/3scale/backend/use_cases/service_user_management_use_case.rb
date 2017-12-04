module ThreeScale
  module Backend
    class ServiceUserManagementUseCase

      def initialize(service, username = nil)
        @service = service
        @username = username
      end

      def add
        storage.sadd(@service.storage_key("user_set"), @username)
      end

      def exists?
        storage.sismember @service.storage_key("user_set"), @username
      end

      def delete
        storage.srem @service.storage_key("user_set"), @username
      end

      private

      def storage
        Service.storage
      end

    end
  end
end
