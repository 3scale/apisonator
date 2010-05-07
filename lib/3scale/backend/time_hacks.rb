module ThreeScale
  module Backend
    module TimeHacks
      ONE_MINUTE = 60
      ONE_HOUR   = 60 * ONE_MINUTE
      ONE_DAY    = 24 * ONE_HOUR
        
      def beginning_of_cycle(cycle)
        case cycle
        when :year   then ::Time.local(year, 1, 1)
        when :month  then ::Time.local(year, month, 1)
        when :week   then beginning_of_week
        when :day    then beginning_of_day
        when :hour   then ::Time.local(year, month, day, hour)
        when :minute then ::Time.local(year, month, day, hour, min)
        when Numeric then beginning_of_numeric_cycle(cycle)
        else
          raise_invalid_period(cycle)
        end
      end

      def beginning_of_week
        # This is stolen from active_support and slightly modified. 
        days_to_monday = wday != 0 ? wday - 1 : 6
        (self - days_to_monday * ONE_DAY).beginning_of_day
      end

      def beginning_of_day
        self.class.local(year, month, day)
      end

      # Formats the time using as little characters as possible, but still keeping
      # readability.
      #
      # == Examples
      #
      # Time.local(2010, 5, 6, 17, 24, 22).to_compact_s # "20100506172422"
      # Time.local(2010, 5, 6, 17, 24, 00).to_compact_s # "201005061724"
      # Time.local(2010, 5, 6, 17, 00, 00).to_compact_s # "2010050617"
      # Time.local(2010, 5, 6, 00, 00, 00).to_compact_s # "20100506"
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
        when 0..ONE_MINUTE        then ::Time.local(year, month, day, hour, min)
        when ONE_MINUTE..ONE_HOUR then ::Time.local(year, month, day, hour)
        when ONE_HOUR..ONE_DAY    then ::Time.local(year, month, day)
        else raise ArgumentError, "Argument must be duration from 0 seconds to 1 day."
        end
      end
      
      def raise_invalid_period(period)
        raise ArgumentError, "Argument must be a number or one of :minute, :hour, :day, :week, :month, or :year, not #{period.inspect}" 
      end
    end
  end
end

Time.send(:include, ThreeScale::Backend::TimeHacks)
