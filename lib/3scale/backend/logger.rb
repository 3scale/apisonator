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

      def self.enable!(on:, with: [], as: :logger)
        logger = if with.empty?
                   ThreeScale::Backend.logger
                 else
                   ThreeScale::Backend::Logger.new(*with).tap do |l|
                     yield l if block_given?
                   end
                 end
        on.send :define_method, as do
          logger
        end
      end
    end
  end
end
