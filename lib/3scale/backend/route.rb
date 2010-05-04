module ThreeScale
  module Backend
    class Route
      def initialize(method, path, action)
        @method = method.to_s.upcase
        @path   = path
        @action = action
      end

      attr_reader :action

      def matches?(env)
        env['REQUEST_METHOD'] == @method &&
        env['PATH_INFO'] == @path
      end
    end
  end
end
