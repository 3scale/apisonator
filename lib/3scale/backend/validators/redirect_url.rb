module ThreeScale
  module Backend
    module Validators
      class RedirectUrl < Base
        def apply
          if params[:redirect_url].nil? || params[:redirect_url].empty? || application.redirect_url == params[:redirect_url]
            succeed!
          else
            fail!(RedirectUrlInvalid.new(params[:redirect_url]))
          end
        end
      end
    end
  end
end
