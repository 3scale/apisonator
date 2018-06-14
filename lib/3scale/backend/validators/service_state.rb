module ThreeScale
  module Backend
    module Validators
      class ServiceState < Base
        def apply
          if service.active?
            succeed!
          else
            fail!(ServiceNotActive.new)
          end
        end
      end
    end
  end
end
