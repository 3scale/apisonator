module ThreeScale
  module Backend
    module StorageKeyHelpers
      KEY_TAG = 'service'

      # Convert any value into storage key.
      def key_for(*args)
        if args.size > 1
          key_for(args)
        else
          case object = args.first
          when Hash
            object.map { |key, value| encode_pair(key, value) }.join('/')
          when Array
            object.map { |part| key_for(part) }.join('/')
          else
            encode_key(object)
          end
        end
      end

      def encode_pair(key, value)
        key = encode_key(key)
        value = encode_key(value)
        
        pair = "#{key}:#{value}"
        pair = "{#{pair}}" if key == KEY_TAG
        pair
      end
      
      def encode_key(key)
        key.to_param.to_s.gsub(/\s/, '+')
      end

      def decode_key(key)
        key.gsub('+', ' ')
      end
    end
  end
end
