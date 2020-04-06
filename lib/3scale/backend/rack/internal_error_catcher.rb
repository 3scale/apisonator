module ThreeScale
  module Backend
    module Rack

      # This middleware should be the last one to run. If there's an exception,
      # instead of propagating it to the web server, we set our own error
      # message. The reason is that each web server handles this differently.
      # Puma returns a generic error message, while Falcon returns the message
      # of the exception.
      class InternalErrorCatcher
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        rescue
          [500, {}, ["Internal Server Error\n".freeze]]
        end
      end
    end
  end
end
