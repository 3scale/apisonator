module ThreeScale
  module Backend
    class Router
      def initialize
        route :post, '/transactions.xml',           Actions::Report
        route :get,  '/transactions/authorize.xml', Actions::Authorize
        route :get,  '/check.txt',                  Actions::Check
      end

      def call(env)
        route = routes.find { |route| route.matches?(env) }
        route && route.action.call(env) || not_found
      end

      private

      attr_reader :routes

      def route(method, path_pattern, action)
        @routes ||= []
        @routes << Route.new(method, path_pattern, action)
      end

      def not_found
        [404, {}, []]
      end
    end
  end
end
