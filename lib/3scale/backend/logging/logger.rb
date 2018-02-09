# Add an application-wide logger UNRELATED to the request's logs.
#
# This allows for additional instrumentation and information gathering
# in production environment.
#
require 'logger'

module ThreeScale
  module Backend
    module Logging
      class Logger
        def self.new(*args)
          ::Logger.new(*args)
        end
      end
    end
  end
end
