module ThreeScale
  module Backend
    describe Usage do
      let(:a_base_value) { 7 }
      let(:a_set_value) { 47 }
      let(:a_set_str) { "##{a_set_value}" }
      let(:an_increment_str) { '69' }
      let(:an_increment_value) { an_increment_str.to_i }
      let(:garbage) { 'garbage' }
      let(:not_sets) { [an_increment_str, garbage] }

      describe '.is_set?' do
        it 'returns truthy when a set is specified' do
          expect(described_class.is_set? a_set_str).to be_truthy
        end

        it 'returns falsey when a non-set is specified' do
          not_sets.each do |item|
            expect(described_class.is_set? item).to be_falsey
          end
        end
      end

      describe '.get_from' do
        context 'when an increment is specified' do
          it 'returns the base value plus the increment' do
            expect(
              described_class.get_from an_increment_str, a_base_value
            ).to be(a_base_value + an_increment_value)
          end

          it 'returns just the increment when no base is specified' do
            expect(
              described_class.get_from an_increment_str
            ).to be(an_increment_value)
          end
        end

        context 'when a set is specified' do
          it 'returns the set value regardless of the base' do
            expect(
              described_class.get_from a_set_str, a_base_value
            ).to be(a_set_value)
          end

          it 'returns just the set value when no base is specified' do
            expect(
              described_class.get_from a_set_str
            ).to be(a_set_value)
          end
        end
      end
    end
  end
end
