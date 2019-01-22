module ThreeScale
  module Backend
    module Stats
      class PartitionGenerator
        def initialize(key_gen)
          @key_gen = key_gen
        end

        def partitions(size)
          0.step(@key_gen.keys.count, size)
        end
      end
    end
  end
end
