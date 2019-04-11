module ThreeScale
  module Backend
    module TimeHacks
      ONE_MINUTE = 60
      ONE_HOUR   = 60 * ONE_MINUTE
      ONE_DAY    = 24 * ONE_HOUR

      def beginning_of_bucket(seconds_in_bucket)
        if seconds_in_bucket > 30 || seconds_in_bucket < 1 || !seconds_in_bucket.is_a?(Fixnum)
          raise Exception, "seconds_in_bucket cannot be larger than 30 seconds or smaller than 1"
        end
        norm_sec = (sec/seconds_in_bucket)*seconds_in_bucket
        self.class.utc(year, month, day, hour, min, norm_sec)
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
      #
      # Careful with cases where hours, minutes or seconds have 2 digits and
      # the second one is a 0. You might find them a bit counter-intuitive
      # (notice the missing 0 at the end of the resulting string):
      # Time.utc(2016, 1, 2, 10, 11, 10).to_compact_s # "2016010210111"
      # Time.utc(2016, 1, 2, 18, 10, 0).to_compact_s # "20160102181"
      # Time.utc(2016, 1, 2, 10, 0, 0).to_compact_s # "201601021"
      #
      # That behavior does not happen with days ending with a 0:
      # Time.utc(2016, 1, 20, 0, 0, 0).to_compact_s # "20160120"

      # Leap seconds would map to 60, so include it.
      MODS = 61.times.map do |i|
        i % 10
      end.freeze
      private_constant :MODS

      DIVS = 61.times.map do |i|
        i / 10
      end.freeze
      private_constant :DIVS

      # This function is equivalent to:
      # strftime('%Y%m%d%H%M%S').sub(/0{0,6}$/, '').
      #
      # When profiling, we found that this method was one of the ones which
      # consumed more CPU time so we decided to optimize it.
      def to_compact_s
        s = year * 10000 +  month * 100 + day
        if sec != 0
          s = s * 100000 + hour * 1000 + min * 10
          MODS[sec] == 0 ? s + DIVS[sec] : s * 10 + sec
        elsif min != 0
          s = s * 1000 + hour * 10
          MODS[min] == 0 ? s + DIVS[min] : s * 10 + min
        elsif hour != 0
          s = s * 10
          MODS[hour] == 0 ? s + DIVS[hour] : s * 10 + hour
        else
          s
        end.to_s
      end

      def to_not_compact_s
        strftime('%Y%m%d%H%M%S')
      end

      private

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
