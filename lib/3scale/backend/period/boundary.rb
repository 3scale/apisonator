module ThreeScale
  module Backend
    module Period
      module Boundary
        module Methods
          ETERNITY_START = Time.utc(1970, 1, 1).freeze
          private_constant :ETERNITY_START
          ETERNITY_FINISH = Time.utc(9999, 12, 31).freeze
          private_constant :ETERNITY_FINISH

          def start_of(period, ts)
            send(:"#{period}_start", ts)
          end

          def end_of(period, ts)
            send(:"#{period}_finish", ts)
          end

          def second_start(ts)
            Time.utc ts.year, ts.month, ts.day, ts.hour, ts.min, ts.sec
          end

          def second_finish(ts)
            second_start(ts) + 1
          end

          def minute_start(ts)
            Time.utc ts.year, ts.month, ts.day, ts.hour, ts.min
          end

          def minute_finish(ts)
            minute_start(ts) + 60
          end

          def hour_start(ts)
            Time.utc ts.year, ts.month, ts.day, ts.hour
          end

          def hour_finish(ts)
            hour_start(ts) + 3600
          end

          def day_start(ts)
            Time.utc ts.year, ts.month, ts.day
          end

          def day_finish(ts)
            day_start(ts) + 86400
          end

          def week_start(ts)
            wday = ts.wday
            days_to_monday = wday != 0 ? wday - 1 : 6
            dayts = ts - days_to_monday * 86400
            Time.utc dayts.year, dayts.month, dayts.day
          end

          def week_finish(ts)
            wday = ts.wday
            days_to_next_monday = wday != 0 ? 8 - wday : 1
            dayts = ts + days_to_next_monday * 86400
            Time.utc dayts.year, dayts.month, dayts.day
          end

          def month_start(ts)
            Time.utc ts.year, ts.month, 1
          end

          def month_finish(ts)
            if ts.month == 12
              year = ts.year + 1
              month = 1
            else
              year = ts.year
              month = ts.month + 1
            end
            Time.utc year, month, 1
          end

          def year_start(ts)
            Time.utc ts.year, 1, 1
          end

          def year_finish(ts)
            Time.utc ts.year + 1, 1, 1
          end

          def eternity_start(_ts)
            ETERNITY_START
          end

          def eternity_finish(_ts)
            ETERNITY_FINISH
          end
        end

        class << self
          include Methods

          def get_callable(period, at)
            method(:"#{period}_#{at}")
          end
        end
      end
    end
  end
end
