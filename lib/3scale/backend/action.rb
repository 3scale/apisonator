module ThreeScale
  module Backend
    class Action

      def self.call(env)
        new.call(env)
      end

      def call(env)
        perform(Rack::Request.new(env))
      end

      def perform(request)
        raise 'Please define a method called "perform"'        
      end
    end
  end
end
