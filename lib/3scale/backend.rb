# load the bundler shim
require_relative 'bundler_shim'

require 'builder'
require 'hiredis-client'

require 'redis'
require 'redis_client/config/timeout' # Monkey patch redis-client

require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'yaml'
require 'digest/md5'

# Require here the classes needed for configuring Backend
require '3scale/backend/environment'
require '3scale/backend/version'
require '3scale/backend/constants'
require '3scale/backend/configuration'
require '3scale/backend/util'
require '3scale/backend/manifest'
require '3scale/backend/logging'

# A lot of classes depend on the required modules above, so don't place them
# above this point.
require '3scale/backend/logging/middleware'
require '3scale/backend/period'
require '3scale/backend/storage_helpers'
require '3scale/backend/storage_key_helpers'
require '3scale/backend/storable'
require '3scale/backend/usage'
require '3scale/backend/rack'
require '3scale/backend/extensions'
require '3scale/backend/background_job'
require '3scale/backend/storage'
require '3scale/backend/memoizer'
require '3scale/backend/application'
require '3scale/backend/error_storage'
require '3scale/backend/metric'
require '3scale/backend/service'
require '3scale/backend/queue_storage'
require '3scale/backend/errors'
require '3scale/backend/stats'
require '3scale/backend/usage_limit'
require '3scale/backend/alerts'
require '3scale/backend/event_storage'
require '3scale/backend/worker'
require '3scale/backend/service_token'
require '3scale/backend/distributed_lock'
require '3scale/backend/failed_jobs_scheduler'
require '3scale/backend/transactor'
require '3scale/backend/listener'

module ThreeScale
  module Backend
    class << self
      def new_resque_redis
        QueueStorage.connection(
          environment,
          configuration,
          )
      end

      def set_resque_redis
        ::Resque.redis = new_resque_redis
      end
    end
  end
end

ThreeScale::Backend.set_resque_redis
