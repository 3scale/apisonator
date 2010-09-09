module ThreeScale
  module Backend
    module JsonSerialization
      private
      
      def json_encode(stuff)
        Yajl::Encoder.encode(stuff)
      end

      def json_decode(encoded_stuff)
        stuff = Yajl::Parser.parse(encoded_stuff).symbolize_keys
        stuff[:timestamp] = Time.parse_to_utc(stuff[:timestamp]) if stuff[:timestamp]
        stuff
      end
    end
  end
end
