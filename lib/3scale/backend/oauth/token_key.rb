# This module defines the format of the keys for OAuth tokens and token sets.
#
# Note that while we can build the key easily, we cannot reliably obtain a token
# and a service_id out of the key, because there are no constraints on them:
#
# "oauth_access_tokens/service:some/servicegoeshere/andthisis_a_/valid_token"
#
module ThreeScale
  module Backend
    module OAuth
      class Token
        module Key
          class << self
            def for(token, service_id)
              "oauth_access_tokens/service:#{service_id}/#{token}"
            end
          end

          module Set
            class << self
              def for(service_id, app_id)
                "oauth_access_tokens/service:#{service_id}/app:#{app_id}/"
              end
            end
          end
        end
      end
    end
  end
end
