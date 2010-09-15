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

      def storage
        Storage.instance
      end
    end
  end
end
