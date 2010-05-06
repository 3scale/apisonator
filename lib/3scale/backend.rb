ENV['RACK_ENV'] ||= 'development'

require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'yaml'

module ThreeScale
  module Backend
    def self.environment
      ENV['RACK_ENV']
    end
  end
end

require '3scale/backend/configuration'
require '3scale/backend/errors'
require '3scale/backend/application'
require '3scale/backend/numeric_hash'
require '3scale/backend/storage'
require '3scale/backend/time_hacks'
