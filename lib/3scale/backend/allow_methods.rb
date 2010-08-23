module ThreeScale
  module Backend
    module AllowMethods
      # Define http methods allowed for a path. This makes the application respond correctly
      # to an OPTIONS request against the given path.
      #
      # Example:
      #
      #   allow_method '/foos/:id', :get, :put, :delete
      #
      def allow_methods(path, *methods)
        route 'OPTIONS', path do
          headers['Allow'] = methods.map(&:to_s).map(&:upcase).join(', ')
          status 200
        end
      end
    end
  end
end
