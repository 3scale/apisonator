module ThreeScale
  module Backend
    module API
      module InternalAPI

        def self.registered(app)
          app.register ServicesAPI
        end
      end
    end
  end
end

require_relative 'services_api'
