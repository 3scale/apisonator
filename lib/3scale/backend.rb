ENV['RACK_ENV'] = 'development' if ENV['RACK_ENV'].nil? || ENV['RACK_ENV'].empty?

require 'aws/s3'
require 'builder'
require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'hoptoad_notifier'
require 'time'
require 'yaml'
require 'zlib'

# Load source files.
require '3scale/backend/configuration'
Dir[File.dirname(__FILE__) + '/**/*.rb'].each { |file| require file }

# Load configuration
# TODO: make the location of the config file configurable too.
require 'configuration'
