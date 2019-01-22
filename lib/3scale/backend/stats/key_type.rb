module ThreeScale
  module Backend
    module Stats
      class KeyType
        attr_reader :key_formatter, :key_parts

        def initialize(key_formatter)
          @key_formatter = key_formatter
          @key_parts = []
        end

        def <<(keypart)
          key_parts << keypart
        end

        def generator
          key_part_chain_head = build_key_part_chain
          key_part_chain_head.generator.lazy.map { |key_data| key_formatter.get_key(key_data) }
        end

        private

        class KeyPartElement
          attr_reader :key_part
          attr_accessor :next_key_part_element

          def initialize(key_part)
            @key_part = key_part
            @next_key_part_element = nil
          end

          def generator
            Enumerator.new do |yielder|
              # combine keys from all keyparts
              # recursive cartessian product generator
              key_part.keypart_elems.each do |key_part_elem|
                next_key_part_element.generator.each do |next_key_part_elem|
                  yielder << key_part_elem.merge(next_key_part_elem)
                end
              end
            end
          end
        end

        class EmptyKeyPartElement
          def generator
            [{}]
          end
        end

        # Build linked lists of KeyPart generators
        # Last element is EmptyKeyPartElement
        def build_key_part_chain
          key_part_list = key_parts.map { |key_part| KeyPartElement.new(key_part) }
          key_part_list.each_cons(2) { |parent, child| parent.next_key_part_element = child }
          key_part_list.last.next_key_part_element = EmptyKeyPartElement.new
          key_part_list.first
        end
      end
    end
  end
end
