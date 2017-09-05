module ThreeScale
  module Backend
    module StorageKeyHelpers
      def encode_key(key)
        key.to_s.tr(' ', '+')
      end
    end
  end
end
