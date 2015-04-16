# Add an application-wide logger UNRELATED to the request's logs.
#
# This allows for additional instrumentation and information gathering
# in production environment.
#
require 'logger'

module ThreeScale
  module Backend
    class Logger
      def self.new(*args)
        ::Logger.new(*args)
      end
    end

    # include this module to have a handy access to the default logger
    module Logging
      def logger
        @logger ||= ThreeScale::Backend.logger
      end
    end
  end
end

Dir[File.dirname(__FILE__) + '/logger/**/*.rb'].each { |file| require file }
