require '3scale/backend/logger/writer'
require '3scale/backend/logger/text_writer'
require '3scale/backend/logger/json_writer'

module ThreeScale
  module Backend
    class Logger
      class Middleware
        def initialize(app, writers: [TextWriter.new])
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

          header = Rack::Utils::HeaderHash.new(header)
          body = Rack::BodyProxy.new(body) do
            @writers.each do |writer|
              writer.log(env, status, header, began_at)
            end
          end

          [status, header, body]
        end
      end
    end
  end
end
