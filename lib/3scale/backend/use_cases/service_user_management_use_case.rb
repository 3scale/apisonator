module ThreeScale
  module Backend
    class ServiceUserManagementUseCase

      def initialize(service, username = nil)
        @service = service
        @username = username
      end

      def add
        isnew = storage.sadd(@service.storage_key("user_set"), @username)
        @service.bump_version

        return isnew
      end

      def exists?
        storage.sismember @service.storage_key("user_set"), @username
      end

      def delete
        deleted = storage.srem @service.storage_key("user_set"), @username
        @service.bump_version

        deleted
      end

      private

      def storage
        Service.storage
      end

    end
  end
end
