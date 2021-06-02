module ThreeScale
  module Backend
    module Validators
      class OauthSetting < Base
        def apply
          if service.backend_version == 'oauth'.freeze
            succeed!
          else
            fail!(OauthNotEnabled.new)
          end
        end
      end
    end
  end
end
