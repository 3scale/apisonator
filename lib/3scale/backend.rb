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
Dir[File.dirname(__FILE__) + '/**/*.rb'].each do |file|
  require file unless file == __FILE__ 
end
