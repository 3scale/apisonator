require '3scale/backend/storage_sync'

module ThreeScale
  module Backend
    class Storage
      include Configurable

      # Require async code conditionally to avoid potential side-effects
      if configuration.redis.async
        require '3scale/backend/storage_async'
      end

      # Constant used for when batching of operations
      # is desired/needed. Batching is performed when a lot
      # of storage operations are need to be performed and we
      # want to minimize database blocking of other clients
      BATCH_SIZE = 400

      class << self
        def instance(reset = false)
          storage_client_class.instance(reset)
        end

        def new(options)
          storage_client_class.new(options)
        end

        private

        def storage_client_class
          if configuration.redis.async
            Backend::StorageAsync::Client
          else
            Backend::StorageSync
          end
        end
      end
    end
  end
end
