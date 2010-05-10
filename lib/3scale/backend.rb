ENV['RACK_ENV'] ||= 'development'

require 'aws/s3'
require 'builder'
require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'time'
require 'yaml'
require 'zlib'

module ThreeScale
  module Backend
    def self.environment
      ENV['RACK_ENV']
    end
  end
end

# Load all source files.
Dir[File.dirname(__FILE__) + '/**/*.rb'].each { |file| require file }
