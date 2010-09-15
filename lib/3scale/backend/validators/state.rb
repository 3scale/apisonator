module ThreeScale
  module Backend
    module Validators
      class State < Base
        def apply
          if application.active?
            succeed!
          else
            fail!(ApplicationNotActive.new)
          end
        end
      end
    end
  end
end
