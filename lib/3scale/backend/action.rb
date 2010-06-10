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
        
      private

      def content_type(request)
        case request.api_version
        when '1.0' then 'application/xml'
        else            'application/vnd.3scale-v1.1+xml'
        end
      end
    end
  end
end
