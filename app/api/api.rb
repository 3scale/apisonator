module ThreeScale
  module Backend
    module API

      def self.registered(app)
        app.register InternalAPI
      end

    end
  end
end

require_relative 'internal/internal_api'
