module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Stats
            def initialize(service_context, limits = nil)
              @key_type_generator = Type.new(service_context, limits)
            end

            def get_key_type_index_generator
              key_type_generator.get_generator.lazy.map(&:key_index)
            end

            def get_key_type_key_generator
              key_type_generator.get_generator.lazy.map(&:key_name)
            end

            private

            attr_reader :key_type_generator
          end
        end
      end
    end
  end
end