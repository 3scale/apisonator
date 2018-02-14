require '3scale/backend/logging/middleware/writer'
require '3scale/backend/logging/middleware/text_writer'
require '3scale/backend/logging/middleware/json_writer'

module ThreeScale
  module Backend
    module Logging
      class Middleware
        WRITERS = { text: TextWriter, json: JsonWriter }.freeze
        private_constant :WRITERS

        DEFAULT_WRITERS = [WRITERS[:text].new].freeze
        private_constant :DEFAULT_WRITERS

        class UnsupportedLoggerType < StandardError
          def initialize(logger)
            super "#{logger} is not a supported logger type."
          end
        end

        # writers is an array of symbols. WRITERS contains the accepted values
        def initialize(app, writers: DEFAULT_WRITERS)
          @app = app
          @writers = writers
        end

        def call(env)
          began_at = Time.now
          begin
            status, header, body = @app.call(env)
          rescue Exception => e
            @writers.each do |writer|
              writer.log_error(env, 500, e.message, began_at)
            end
            raise e
          end

          header = ::Rack::Utils::HeaderHash.new(header)
          body = ::Rack::BodyProxy.new(body) do
            @writers.each do |writer|
              writer.log(env, status, header, began_at)
            end
          end

          [status, header, body]
        end

        # Returns the Writer instances that correspond to the loggers given.
        # If no loggers are given, returns the default writers.
        def self.writers(loggers)
          writers = Array(loggers).map do |logger|
            writer_class =  WRITERS[logger]
            raise UnsupportedLoggerType.new(logger) unless writer_class
            writer_class.new
          end

          writers.empty? ? DEFAULT_WRITERS : writers
        end
      end
    end
  end
end
