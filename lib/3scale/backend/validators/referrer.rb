module ThreeScale
  module Backend
    module Validators
      class Referrer < Base
        def apply
          if application.has_referrer_filters?
            if application.has_referrer_filter?(params[:referrer])
              succeed!
            else
              fail!(ReferrerNotAllowed.new(params[:referrer]))
            end
          else
            succeed!
          end
        end

        # TODO: wildcard domain match: *.example.org
        # TODO: ip match
        # TODO: ip subnet match
      end
    end
  end
end
