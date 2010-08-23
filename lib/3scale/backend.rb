require '3scale/core'
require 'aws/s3'
require 'builder'
require 'redis'
require 'fiber'
require 'ostruct'
require 'rack/hoptoad'
require 'rack/rest_api_versioning'
require 'resque'
require 'securerandom'
require 'sinatra/base'
require 'time'
require 'yajl'
require 'zlib'

require '3scale/backend/configuration'
require '3scale/backend/extensions'

module ThreeScale
  module Backend
    autoload :Aggregator,             '3scale/backend/aggregator'
    autoload :AllowMethods,           '3scale/backend/allow_methods'
    autoload :Application,            '3scale/backend/application'
    autoload :Archiver,               '3scale/backend/archiver'
    autoload :Endpoint,               '3scale/backend/endpoint'
    autoload :ErrorReporter,          '3scale/backend/error_reporter'
    autoload :Metric,                 '3scale/backend/metric'
    autoload :Runner,                 '3scale/backend/runner'
    autoload :Serializers,            '3scale/backend/serializers'
    autoload :Server,                 '3scale/backend/server'
    autoload :Service,                '3scale/backend/service'
    autoload :Storage,                '3scale/backend/storage'
    autoload :Transactor,             '3scale/backend/transactor'
    autoload :UsageLimit,             '3scale/backend/usage_limit'
    autoload :Worker,                 '3scale/backend/worker'
   
    autoload :ApplicationKeyInvalid,  '3scale/backend/errors'
    autoload :ApplicationKeyNotFound, '3scale/backend/errors'
    autoload :ApplicationNotActive,   '3scale/backend/errors'
    autoload :ApplicationNotFound,    '3scale/backend/errors'
    autoload :Error,                  '3scale/backend/errors'
    autoload :LimitsExceeded,         '3scale/backend/errors'
    autoload :MetricInvalid,          '3scale/backend/errors'
    autoload :ProviderKeyInvalid,     '3scale/backend/errors'
    autoload :UnsupportedApiVersion,  '3scale/backend/errors'
    autoload :UsageValueInvalid,      '3scale/backend/errors'
  end

  module Core
    def self.storage
      ThreeScale::Backend::Storage.instance
    end
  end
end

ThreeScale::Backend.configuration.tap do |config|
  # Add configuration sections
  config.add_section(:aws, :access_key_id, :secret_access_key)
  config.add_section(:redis, :servers, :db, :backup_file)
  config.add_section(:archiver, :path, :s3_bucket)
  config.add_section(:hoptoad, :api_key)

  # Default config
  config.master_service_id = 1
  config.archiver.path     = '/tmp/3scale_backend/archive'

  # Load configuration from a file.
  config.load!
end

Resque.redis = ThreeScale::Backend::Storage.instance
