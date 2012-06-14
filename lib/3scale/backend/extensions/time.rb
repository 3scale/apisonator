module ThreeScale
  module Backend
    module TimeHacks
      ONE_MINUTE = 60
      ONE_HOUR   = 60 * ONE_MINUTE
      ONE_DAY    = 24 * ONE_HOUR
        
      def beginning_of_cycle(cycle)
        case cycle
        when :eternity then self.class.utc(1970, 1, 1)
        when :year     then self.class.utc(year, 1, 1)
        when :month    then self.class.utc(year, month, 1)
        when :week     then beginning_of_week
        when :day      then beginning_of_day
        when :hour     then self.class.utc(year, month, day, hour)
        when :minute   then self.class.utc(year, month, day, hour, min)
        when Numeric   then beginning_of_numeric_cycle(cycle)
        else
          raise_invalid_period(cycle)
        end
      end

      def end_of_cycle(cycle)
        case cycle
        ## a WTF take-away for future generations
        when :eternity then self.class.utc(9999, 12, 31)
        when :year     then self.class.utc(year + 1, 1, 1)
        when :month    then end_of_month_hack
        when :week     then end_of_week_hack
        when :day      then beginning_of_day_hack + ONE_DAY
        when :hour     then beginning_of_cycle(:hour) + ONE_HOUR
        when :minute   then beginning_of_cycle(:minute) + ONE_MINUTE
        else
          raise_invalid_period(cycle)
        end
      end

      def end_of_month_hack
        if month == 12
          end_of_cycle(:year)
        else
          self.class.utc(year, month + 1, 1)
        end
      end

      def beginning_of_week_hack
        # This is stolen from active support and slightly modified
        days_to_monday = wday != 0 ? wday - 1 : 6
        (self - days_to_monday * ONE_DAY).beginning_of_day
      end

      def end_of_week_hack
        days_to_next_monday = wday != 0 ? 8 - wday : 1
        (self + days_to_next_monday * ONE_DAY).beginning_of_day
      end

      def beginning_of_day_hack
        self.class.utc(year, month, day)
      end

      # Formats the time using as little characters as possible, but still keeping
      # readability.
      #
      # == Examples
      #
      # Time.utc(2010, 5, 6, 17, 24, 22).to_compact_s # "20100506172422"
      # Time.utc(2010, 5, 6, 17, 24, 00).to_compact_s # "201005061724"
      # Time.utc(2010, 5, 6, 17, 00, 00).to_compact_s # "2010050617"
      # Time.utc(2010, 5, 6, 00, 00, 00).to_compact_s # "20100506"
      def to_compact_s
        strftime('%Y%m%d%H%M%S').sub(/0{0,6}$/, '')
      end

      private
      
      def beginning_of_numeric_cycle(cycle)
        base = cycle_base(cycle)

        cycles_count = ((self - base) / cycle).floor
        base + cycles_count * cycle
      end
      
      def cycle_base(cycle)
        case cycle
        when 0..ONE_MINUTE        then ::Time.utc(year, month, day, hour, min)
        when ONE_MINUTE..ONE_HOUR then ::Time.utc(year, month, day, hour)
        when ONE_HOUR..ONE_DAY    then ::Time.utc(year, month, day)
        else raise ArgumentError, "Argument must be duration from 0 seconds to 1 day."
        end
      end
      
      def raise_invalid_period(period)
        raise ArgumentError, "Argument must be a number or one of :minute, :hour, :day, :week, :month, or :year, not #{period.inspect}" 
      end
      
      module ClassMethods
        def parse_to_utc(input)
          parts = nil

          begin
            parts = Date._parse(input.to_s)
          rescue TypeError => e
          end

          return if parts.nil? || parts.empty? || !parts.has_key?(:year) || !parts.has_key?(:mon) || !parts.has_key?(:mday) 

          time = nil
          begin
            time = Time.utc(parts[:year],
                            parts[:mon],
                            parts[:mday],
                            parts[:hour],
                            parts[:min],
                            parts[:sec],
                            parts[:sec_fraction])
            time -= parts[:offset] if parts[:offset]
            
          rescue ArgumentError => e
          end

          return time
        end
      end
    end
  end
end

Time.send(:include, ThreeScale::Backend::TimeHacks)
Time.extend(ThreeScale::Backend::TimeHacks::ClassMethods)
