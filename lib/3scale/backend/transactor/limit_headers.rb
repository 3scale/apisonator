module ThreeScale
  module Backend
    module Transactor
      module LimitHeaders
        class << self
          # Note: -1 is used in the remaining of usage reports to indicate that
          # there is no limit.

          UNCONSTRAINED = { remaining: -1, reset: -1 }.freeze
          private_constant :UNCONSTRAINED

          def get(reports, now = Time.now.utc)
            report = most_constrained_report reports
            if report && report.remaining_same_calls != -1
              {
                remaining: report.remaining_same_calls,
                reset: report.remaining_time(now),
                'max-value': report.max_value
              }
            else
              UNCONSTRAINED
            end
          end

          private

          # Will return the most constrained report
          def most_constrained_report(reports)
            reports.min do |a, b|
              compare a, b
            end
          end

          # Warning: comparison here returns from most to least constrained
          # usage report (ie. in descending order)
          def compare(one, other)
            other_rem = other.remaining_same_calls
            one_rem = one.remaining_same_calls
            if one_rem == other_rem
              # Note: the line below is correctly reversing the operands
              # This is done to have the larger period ordered before the
              # shorter ones when the remaining hits are the same.
              other.period.granularity <=> one.period.granularity
            elsif other_rem == -1 || one_rem < other_rem
              -1
            else
              1
            end
          end
        end
      end
    end
  end
end
