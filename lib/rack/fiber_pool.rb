module Rack
  class FiberPool
    # TODO: This is not really a pool yet. It spawns a new fiber on each request. Also,
    # it lacks any test coverage!

    ASYNC_RESPONSE = [-1, {}, []].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      Fiber.new do
        env['async.callback'].call(@app.call(env))
      end.resume

      ASYNC_RESPONSE
    end
  end
end
