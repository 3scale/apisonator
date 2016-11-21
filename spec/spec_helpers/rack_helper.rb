# Helper classes to set up a minimum Rack env and app for running a request
# through Rack's middleware(s).
#
# Use the Request#run method to have it perform the request.
#
module SpecHelpers
  module Rack
    class App
      # exception raised by the app when failure mode is enabled
      Error = Class.new StandardError

      attr_reader :status, :body, :app

      def initialize(status: 200, resp_headers: {}, body: '', failure: false)
        @status = status
        @resp_headers = resp_headers
        @body = body
        @app = failure ? app_failure : app_ok
      end

      def app_ok
        lambda do |env|
          [@status, @resp_headers, @body]
        end
      end

      def app_failure
        lambda do |env|
          raise exception
        end
      end

      def exception
        @exception ||= Error.new('the Rack application raised')
      end
    end

    class Request
      attr_reader :status, :http_method, :path, :query_string, :env

      def initialize(http_method: 'GET', path: '/somepath', query_string: '',
                     headers: {}, failure: false, **env)
        @http_method = http_method.to_s.upcase
        @path = path
        @query_string = query_string
        @env = {
          'REQUEST_METHOD' => @http_method,
          'PATH_INFO' => @path,
          'QUERY_STRING' => @query_string,
          'HTTP_VERSION' => 'HTTP/1.1'
        }.merge(env).merge(headers)
      end

      def run(middleware)
        _, _, body = middleware.call(@env)
        body.close
      end
    end
  end
end
