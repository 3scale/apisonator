ENV['RACK_ENV'] ||= 'development'

# Gems
require 'eventmachine'
require 'em-redis'

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
require '3scale/backend/storage'
