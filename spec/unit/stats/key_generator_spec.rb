require_relative '../../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::KeyGenerator do
  context '#keys' do
    let(:key_type_a) { double('key_type_a', generator: %w[key_a_00 key_a_01]) }
    let(:key_type_b) { double('key_type_b', generator: %w[key_b_00]) }
    let(:key_type_c) { double('key_type_c', generator: []) }
    let(:key_types) { [key_type_a, key_type_b, key_type_c] }
    subject { described_class.new(key_types).keys }
    it { is_expected.to match_array(%w[key_a_00 key_a_01 key_b_00]) }
  end
end
