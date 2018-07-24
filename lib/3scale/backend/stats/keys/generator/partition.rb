# Create a keys partition generator
module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Partition
            include Enumerable

            def initialize(key_generator, options = {})
              @keys_slice = options[:keys_slice] || DEFAULT_KEYS_SLICE
              @key_generator = key_generator
              @key_partition_generator = Enumerator.new do |enum|
                @key_generator.each_slice(keys_slice) do |slice|
                  # Only use the first and last element of the range
                  # of generated keys. This will mark the begin
                  # mark and the end mark of keys to delete
                  enum << [slice.first, slice.last]
                end
              end
            end

            # TODO check if an enumerator can be returned from this if not
            # called with a block
            def each(&block)
              key_partition_generator.each(&block)
            end

            private

            attr_accessor :keys_slice, :key_generator, :key_partition_generator

            # It is 20*50 because we want 20 batches of 50 keys
            # to delete in Redis in the resque deletion job
            DEFAULT_KEYS_SLICE = 20*50
            private_constant :DEFAULT_KEYS_SLICE
          end
        end
      end
    end
  end
end
