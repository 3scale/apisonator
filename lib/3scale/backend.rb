ENV['RACK_ENV'] = 'development' if ENV['RACK_ENV'].nil? || ENV['RACK_ENV'].empty?

require 'aws/s3'
require 'builder'
require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'hoptoad_notifier'
require 'ostruct'
require 'time'
require 'yaml'
require 'zlib'

require '3scale/backend/configuration'
require '3scale/backend/time_hacks'

module ThreeScale
  module Backend
    autoload :Action,             '3scale/backend/action'
    autoload :Actions,            '3scale/backend/actions'
    autoload :Aggregation,        '3scale/backend/aggregation'
    autoload :Archiver,           '3scale/backend/archiver'
    autoload :Route,              '3scale/backend/route'
    autoload :Router,             '3scale/backend/router'
    autoload :StorageKeyHelpers,  '3scale/backend/storage_key_helpers'
    autoload :Transactor,         '3scale/backend/transactor'
   
    autoload :ContractNotActive,  '3scale/backend/errors'
    autoload :Error,              '3scale/backend/errors'
    autoload :LimitsExceeded,     '3scale/backend/errors'
    autoload :MetricNotFound,     '3scale/backend/errors'
    autoload :MultipleErrors,     '3scale/backend/errors'
    autoload :ProviderKeyInvalid, '3scale/backend/errors'
    autoload :UserKeyInvalid,     '3scale/backend/errors'
    autoload :UsageValueInvalid,  '3scale/backend/errors'
    
    # These will be extracted to a separate gem.
    autoload :Contract,           '3scale/backend/contract'
    autoload :Metric,             '3scale/backend/metric'
    autoload :Service,            '3scale/backend/service'
    autoload :Storable,           '3scale/backend/storable'
    autoload :UsageLimit,         '3scale/backend/usage_limit'
  end
end
