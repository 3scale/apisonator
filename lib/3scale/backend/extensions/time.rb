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
      def to_compact_s
        strftime('%Y%m%d%H%M%S').sub(/0{0,6}$/, '')
      end

      def to_not_compact_s
        (year * 10000000000 + month * 100000000 + day * 1000000 +
         hour * 10000 + min * 100 + sec).to_s
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
