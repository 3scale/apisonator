module ThreeScale
  module Backend
    module StorageKeyHelpers
      def encode_key(key)
        key.to_s.gsub(/\s/, '+')
      end

      def decode_key(key)
        key.gsub('+', ' ')
      end
    end
  end
end
