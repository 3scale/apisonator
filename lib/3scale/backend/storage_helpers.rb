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
      
      def redis_key_2_cassandra_key(redis_key)
        v = redis_key.split("/")
        last = v[v.size-1]
        if last=="eternity"
          [redis_key, "eternity"]
        else
          w = last.split(":")
          ["#{v[0..v.size-2].join('/')}/#{w[0]}:#{w[1][0..3]}",w[1]]
        end
      end

      def storage
        Storage.instance
      end
    end
  end
end
