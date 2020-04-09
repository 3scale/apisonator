module ThreeScale
  module Backend
    module Validators
      class Referrer < Base

        # There are some users that depend on a previous version of the
        # pattern_matches? method. We make this configurable to avoid breaking
        # changes for those users.

        class << self
          def define_pattern_match(legacy)
            class_eval do
              if legacy
                def pattern_matches?(pattern, value)
                  /#{pattern}/ =~ value
                end
              else
                def pattern_matches?(pattern, value)
                  /\A#{pattern}\z/ =~ value
                end
              end
            end
          end
          private :define_pattern_match

          def behave_as_legacy(legacy)
            # don't blow up if we still didn't define it
            remove_method :pattern_matches? rescue NameError
            define_pattern_match legacy
          end
          private :behave_as_legacy unless ThreeScale::Backend.test? # leave it public for tests
        end

        behave_as_legacy ThreeScale::Backend.configuration.legacy_referrer_filters

        BYPASS = '*'.freeze
        private_constant :BYPASS

        def apply
          if service.referrer_filters_required? && application.has_referrer_filters?
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
          return true if value == BYPASS
          pattern_matches?(Regexp.escape(pattern).gsub('\*', '.*'), value)
        end
      end
    end
  end
end
