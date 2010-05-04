require '3scale/backend/actions/authorize'
require '3scale/backend/actions/report'

require '3scale/backend/route'

module ThreeScale
  module Backend
    class Application
      def self.call(env)
        new.call(env)
      end

      def initialize
        route :post, '/transactions.xml',           Actions::Report
        route :get,  '/transactions/authorize.xml', Actions::Authorize
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
