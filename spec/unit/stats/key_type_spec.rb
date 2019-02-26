require_relative '../../spec_helper'

class StatsFormatterMock
  def get_key(key_a:, key_b:)
    "#{key_a}-#{key_b}"
  end
end

RSpec.describe ThreeScale::Backend::Stats::KeyType do
  let(:formatter) { StatsFormatterMock.new }
  let(:key_part_a) { double('keypart_a') }
  let(:key_part_b) { double('keypart_b') }
  let(:key_a_01) { 'a_01' }
  let(:key_a_02) { 'a_02' }
  let(:key_b_01) { 'b_01' }
  subject { described_class.new(formatter) }
  let(:expected_keys) { %w[a_01-b_01 a_02-b_01] }

  before(:each) do
    expect(key_part_a).to receive(:keypart_elems).and_return([{ key_a: key_a_01 }, { key_a: key_a_02 }])
    # receives as many calls as previous part elements items. In this case twice.
    expect(key_part_b).to receive(:keypart_elems).twice.and_return([{ key_b: key_b_01 }])
    subject << key_part_a
    subject << key_part_b
  end

  it 'all expected keys are generated' do
    expect(subject.generator.to_a).to match_array expected_keys
  end
end
