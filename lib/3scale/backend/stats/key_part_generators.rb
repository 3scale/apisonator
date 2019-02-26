module ThreeScale
  module Backend
    module Stats
      module KeyPartGenerator
        attr_reader :job
        def initialize(job)
          @job = job
        end
      end

      class AppKeyPartGenerator
        include KeyPartGenerator

        def items
          job.applications.each
        end
      end

      class UserKeyPartGenerator
        include KeyPartGenerator

        def items
          job.users.each
        end
      end

      class MetricKeyPartGenerator
        include KeyPartGenerator

        def items
          job.metrics.each
        end
      end

      class ResponseCodeKeyPartGenerator
        include KeyPartGenerator

        def items
          CodesCommons::TRACKED_CODES + CodesCommons::HTTP_CODE_GROUPS_MAP.values
        end
      end

      module KeyPartPeriodGenerator
        def items
          from, to = [job.from, job.to].map { |t| Time.at(t) }
          Enumerator.new do |yielder|
            curr_time = from
            while curr_time <= to
              yielder << Period[period_id].new(curr_time)
              curr_time = increment curr_time
            end
          end
        end
      end

      class HourKeyPartGenerator
        include KeyPartGenerator
        include KeyPartPeriodGenerator

        def period_id
          :hour
        end

        def increment(timestamp)
          timestamp + 3600
        end
      end

      class DayKeyPartGenerator
        include KeyPartGenerator
        include KeyPartPeriodGenerator

        def period_id
          :day
        end

        def increment(timestamp)
          timestamp + 3600 * 24
        end
      end

      class WeekKeyPartGenerator
        include KeyPartGenerator
        include KeyPartPeriodGenerator

        def period_id
          :week
        end

        def increment(timestamp)
          timestamp + 3600 * 24 * 7
        end
      end

      class MonthKeyPartGenerator
        include KeyPartGenerator
        include KeyPartPeriodGenerator

        def period_id
          :month
        end

        def increment(timestamp)
          (timestamp.to_datetime >> 1).to_time
        end
      end

      class YearKeyPartGenerator
        include KeyPartGenerator
        include KeyPartPeriodGenerator

        def period_id
          :year
        end

        def increment(timestamp)
          (timestamp.to_datetime >> 12).to_time
        end
      end

      class EternityKeyPartGenerator
        include KeyPartGenerator

        def items
          [Period[:eternity].new]
        end
      end

      PERIOD_GENERATOR_MAP = {
        Period[:hour] => HourKeyPartGenerator,
        Period[:day] => DayKeyPartGenerator,
        Period[:week] => WeekKeyPartGenerator,
        Period[:month] => MonthKeyPartGenerator,
        Period[:year] => YearKeyPartGenerator,
        Period[:eternity] => EternityKeyPartGenerator
      }.freeze
    end
  end
end
