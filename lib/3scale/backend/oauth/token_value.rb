# This module encodes values in Redis for our tokens
module ThreeScale
  module Backend
    module OAuth
      class Token
        module Value
          # Note: this module made more sense when it also supported end-users.
          # Given how simple the module is, we could get rid of it in a future
          # refactor.

          class << self
            # this method is used when creating tokens
            def for(app_id)
              app_id
            end

            def from(value)
              value
            end
          end
        end
      end
    end
  end
end
