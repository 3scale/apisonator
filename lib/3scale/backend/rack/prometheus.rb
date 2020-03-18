module ThreeScale
  module Backend
    module Rack
      class Prometheus
        def initialize(app)
          @app = app
        end

        def call(env)
          began_at = Time.now.getutc
          status, header, body = @app.call(env)
          ListenerMetrics.report_resp_code(env['REQUEST_PATH'], status)
          ListenerMetrics.report_response_time(env['REQUEST_PATH'], Time.now - began_at)
          [status, header, body]
        end
      end
    end
  end
end
