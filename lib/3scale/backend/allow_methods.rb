module ThreeScale
  module Backend
    module AllowMethods
      ALLOWABLE_METHODS = ['GET', 'POST', 'PUT', 'DELETE']

      def self.registered(app)
        class << app
          alias_method :route_without_allowed_methods, :route
          alias_method :route, :route_with_allowed_methods
        end
      end

      def route_with_allowed_methods(method, path, options = {}, &block)
        allow_method(method, path) if ALLOWABLE_METHODS.include?(method)
        route_without_allowed_methods(method, path, options, &block)
      end

      def allow_method(method, path)
        @@allowed_methods ||= {}

        unless @@allowed_methods[path]
          route 'OPTIONS', path do
            headers['Allow'] = @@allowed_methods[path].uniq.join(', ')
            status 200
          end

          @@allowed_methods[path] = []
        end

        @@allowed_methods[path] << method
      end
    end
  end
end
