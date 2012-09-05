module ThreeScale
  module Backend
    module StorageHelpers
      private
      
      def encode(stuff)
        Yajl::Encoder.encode(stuff)
      end

      def decode(encoded_stuff)
        stuff = Yajl::Parser.parse(encoded_stuff).symbolize_keys
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
      
      def redis_key_2_cassandra_key(redis_key)
        v = redis_key.split("/")
        last = v[v.size-1]
        if last=="eternity"
          [redis_key, "eternity"]
        else
          w = last.split(":")
          ["#{v[0..v.size-2].join('/')}/#{w[0]}:#{w[1][0..3]}",normalize_time(w[1],w[0])]
        end
      end
      
      def redis_key_2_cassandra_key_inverted(redis_key)
        v = redis_key.split("/")
        last = v[v.size-1]
        ## only consider hours
        w = last.split(":")
        if last!="eternity" && last.split(":")[0]=="hour"
           row_key = normalize_time(w[1],"hour")
           col_key = nil
           col_key = v[1..3].join('/') if v[2].match(/^cinstance/)
           return [row_key, col_key]
        end
        return [nil, nil]
      end

      def storage
        Storage.instance
      end
    end
  end
end
