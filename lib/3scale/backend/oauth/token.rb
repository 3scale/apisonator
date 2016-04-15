module ThreeScale
  module Backend
    module OAuth
      class Token
        attr_reader :service_id, :token, :key
        attr_accessor :ttl, :app_id, :user_id

        # user_id can be nil (most providers do not have Users)
        def initialize(token, service_id, app_id, user_id, ttl)
          @token = token
          @service_id = service_id
          @app_id = app_id
          @user_id = user_id
          @ttl = ttl
          @key = Key.for token, service_id
        end

        def value
          Value.for app_id, user_id
        end

        def self.from_value(token, service_id, value, ttl)
          new token, service_id, *Value.from(value), ttl
        end
      end
    end
  end
end
