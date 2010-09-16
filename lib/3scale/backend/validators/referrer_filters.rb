module ThreeScale
  module Backend
    module Validators
      class ReferrerFilters < Base
        def apply
          if !service.referrer_filters_required? || application.has_referrer_filters?
            succeed!
          else
            fail!(ReferrerFiltersMissing.new)
          end
        end
      end
    end
  end
end
