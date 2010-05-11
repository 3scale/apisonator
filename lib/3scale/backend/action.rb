module ThreeScale
  module Backend
    class Action
      # Returning this, I tell thin (or other webserver) to go asynchronous.
      ASYNC_RESPONSE = [-1, {}, []].freeze

      def self.call(env)
        new.call(env)
      end

      def call(env)
        Fiber.new do
          response = perform(Rack::Request.new(env))
          env['async.callback'].call(response)
        end.resume

        ASYNC_RESPONSE
      end

      def perform(request)
        raise 'Please define a method called "perform"'        
      end
    end
  end
end
