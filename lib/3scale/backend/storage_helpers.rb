module ThreeScale
  module Backend
    module StorageHelpers
      private
      def encode(stuff)
        Yajl::Encoder.encode(stuff)
      end

      def decode(encoded_stuff)
        stuff = Yajl::Parser.parse(encoded_stuff).symbolize_names
        stuff[:timestamp] = Time.parse_to_utc(stuff[:timestamp]) if stuff[:timestamp]
        stuff
      end

      def normalize_time(time_itself, period)
        ## to really understand this crap check test/unit/extensions/time_test.rb # test_end_of_cycle_with_to_compact_s

        period = period.to_sym
        time_itself = time_itself.to_s

        return time_itself[0..3] if period==:year
        return time_itself[0..5] if period==:month
        return time_itself[0..7] if period==:week
        return time_itself[0..7] if period==:day
        return (time_itself + "0"*12)[0..9]  if period==:hour
        return (time_itself + "0"*12)[0..11] if period==:minute
      end

      def storage
        Storage.instance
      end
    end
  end
end
