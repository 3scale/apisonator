module ThreeScale
  module Backend
    module Validators
      class Base
        def self.apply(status, params)
          new(status, params).apply
        end

        def initialize(status, params)
          @status = status
          @params = params
        end

        attr_reader :status
        attr_reader :params

        def service
          @service ||= Service.load_by_id!(status.service_id)
        end

        def application
          status.application
        end

        def succeed!
          true
        end

        def fail!(error)
          status.reject!(error)
          false
        end
      end
    end
  end
end
