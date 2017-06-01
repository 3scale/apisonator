module ThreeScale
  module Backend
    module Validators
      class OauthKey < Base
        def apply
          if params[:app_key].nil? || (!params[:app_key].empty? && application.has_key?(params[:app_key]))
            succeed!
          else
            fail!(ApplicationKeyInvalid.new(params[:app_key]))
          end
        end
      end
    end
  end
end
