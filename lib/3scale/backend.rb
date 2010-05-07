ENV['RACK_ENV'] ||= 'development'

require 'builder'
require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'time'
require 'yaml'

module ThreeScale
  module Backend
    def self.environment
      ENV['RACK_ENV']
    end
  end
end

# Load all source files.
Dir[File.dirname(__FILE__) + '/**/*.rb'].each { |file| require file }
