module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          class Type
            def initialize(service_context, index_limits)
              @service_context = service_context
              @index_limits = index_limits
            end

            def get_generator
              type_idx_lim = get_key_type_limits
              Enumerator.new do |enum|
                KEY_TYPE_GENERATORS[type_idx_lim].each_with_index do |gen, type_idx|
                  key_type_generator = gen.new(service_context, index_limits)
                  key_type_generator.get_generator.each do |elem|
                    elem.key_index.key_type = type_idx
                    enum << elem
                  end
                end
              end
            end

            private

            attr_accessor :service_context
            attr_accessor :index_limits

            # All generators below should implement the
            # 'get_generator' method
            KEY_TYPE_GENERATORS = [
              MetricKeyTypeGenerator,
              AppsKeyTypeGenerator,
              UserKeyTypeGenerator
            ].freeze

            def get_key_type_limits
              # Array range goes from A to B, (B - A + 1) elements
              return Range.new(0, KEY_TYPE_GENERATORS.size - 1) if index_limits.nil?
              Range.new(index_limits[0].key_type, index_limits[1].key_type)
            end
          end
        end
      end
    end
  end
end
