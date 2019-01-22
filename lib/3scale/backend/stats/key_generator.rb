module ThreeScale
  module Backend
    module Stats
      class KeyGenerator
        attr_reader :key_types

        def initialize(key_types)
          @key_types = key_types
        end

        # multiplexing keys from different key types
        def keys
          Enumerator.new do |yielder|
            key_types.each do |key_type|
              key_type.generator.each do |key|
                yielder << key
              end
            end
          end
        end
      end
    end
  end
end
