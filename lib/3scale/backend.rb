ENV['RACK_ENV'] = 'development' if ENV['RACK_ENV'].nil? || ENV['RACK_ENV'].empty?

require 'aws/s3'
require 'builder'
require 'eventmachine'
require 'em-redis'
require 'fiber'
require 'hoptoad_notifier'
require 'optparse'
require 'thin'
require 'time'
require 'yaml'
require 'zlib'

require 'rack/fiber_pool'

# Load source files.
require '3scale/backend/configuration'
Dir[File.dirname(__FILE__) + '/**/*.rb'].each do |file|
  require file unless file == __FILE__ 
end

# Load configuration
# TODO: make the location of the config file configurable too.
require 'configuration'

module ThreeScale
  module Backend
    def self.run(options = {})
      host, port, options = parse_options(options[:argv] || ARGV)

      Thin::Server.start(host, port, options) do
        use HoptoadNotifier::Rack
        use Rack::FiberPool

        run ThreeScale::Backend::Router
      end
    end

    def self.parse_options(argv)
      host    = '0.0.0.0'
      port    = 3000
      options = {}

      OptionParser.new do |parser|
        parser.banner = 'Usage: 3scale_backend [options]'

        parser.on '-a', '--address HOST', 'bind to HOST address (default: 0.0.0.0)' do |value|
          host = value
        end

        parser.on '-p', '--port PORT', 'use PORT (default: 3000)' do |value|
          port = value
        end

        parser.parse!(argv)
      end

      [host, port, options]
    end
  end
end

if $0 == __FILE__
  ThreeScale::Backend.run
end
