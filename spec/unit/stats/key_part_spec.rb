require_relative '../../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::KeyPart do
  let(:id) { :mypart_id }
  let(:part_a_01) { 'a_01' }
  let(:part_a_02) { 'a_01' }
  let(:part_b_01) { 'b_01' }
  let(:part_b_02) { 'b_02' }
  let(:generator_a) { double('generator_a') }
  let(:generator_b) { double('generator_b') }
  subject { described_class.new(id) }
  let(:expected_elems) do
    [
      { mypart_id: part_a_01 },
      { mypart_id: part_a_02 },
      { mypart_id: part_b_01 },
      { mypart_id: part_b_02 }
    ]
  end

  before(:each) do
    expect(generator_a).to receive(:items).and_return([part_a_01, part_a_02])
    expect(generator_b).to receive(:items).and_return([part_b_01, part_b_02])
    subject << generator_a
    subject << generator_b
  end

  it 'all expected elements are generated' do
    expect(subject.keypart_elems.to_a).to match_array expected_elems
  end
end
