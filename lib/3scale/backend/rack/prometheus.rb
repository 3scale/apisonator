module ThreeScale
  module Backend
    module Rack
      class Prometheus
        def initialize(app)
          @app = app
        end

        def call(env)
          began_at = Time.now.getutc

          begin
            status, header, body = @app.call(env)
          rescue Exception => e
            ListenerMetrics.report_resp_code(env['REQUEST_PATH'], 500)
            ListenerMetrics.report_response_time(env['REQUEST_PATH'], Time.now - began_at)
            raise e
          end

          ListenerMetrics.report_resp_code(env['REQUEST_PATH'], status)
          ListenerMetrics.report_response_time(env['REQUEST_PATH'], Time.now - began_at)
          [status, header, body]
        end
      end
    end
  end
end
