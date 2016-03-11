module ThreeScale
  module Backend
    module Validators
      class Referrer < Base
        BYPASS = '*'.freeze
        private_constant :BYPASS

        def apply
          if application.has_referrer_filters?
            if application.referrer_filters.any? { |filter| matches?(filter, params[:referrer]) }
              succeed!
            else
              fail!(ReferrerNotAllowed.new(params[:referrer]))
            end
          else
            succeed!
          end
        end

        private

        def matches?(pattern, value)
          if value == BYPASS
            true
          else
            pattern = Regexp.escape(pattern)
            pattern = pattern.gsub('\*', '.*')

            /\A#{pattern}\z/ =~ value
          end
        end
      end
    end
  end
end
