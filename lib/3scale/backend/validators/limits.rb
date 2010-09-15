module ThreeScale
  module Backend
    module Validators
      class Limits < Base
        def apply
          usage = status.current_values

          if application.usage_limits.all? { |limit| limit.validate(usage) }
            succeed!
          else
            fail!(LimitsExceeded.new)
          end
        end
      end
    end
  end
end
