require_relative '../spec_helper'
require '3scale/backend/alert_limit'

module ThreeScale
  module Backend
    describe AlertLimit do
      let(:service_id)  { 40 }
      let(:value)       { 100 }

      describe '.load_all' do
        context 'when there are no alert limits' do
          subject { AlertLimit.load_all(service_id) }

          it { expect(subject).to be_empty }
        end

        context 'when there are alert limits' do
          let(:values) { [50, 90, 100] }
          before { values.each { |value| AlertLimit.save(service_id, value) } }
          subject { AlertLimit.load_all(service_id) }

          it { expect(subject.size).to eq(values.size) }
          it { expect(subject.map(&:value)).to eq(values) }
        end
      end

      describe '.save' do
        context 'with an invalid value' do
          subject { AlertLimit.save(service_id, 'foo') }

          it { expect(subject).to be nil }
        end

        context 'with a valid value' do
          subject { AlertLimit.save(service_id, value) }

          it { expect(subject).to be_kind_of(AlertLimit) }
          it { expect(subject.value).to eq(value) }
        end
      end

      describe '.delete' do
        context 'with existing value' do
          let(:alert_limit) { AlertLimit.save(service_id, value) }

          subject { AlertLimit.delete(service_id, alert_limit.value) }

          it { expect(subject).to be true }
          it { expect(AlertLimit.load_all(service_id)).to be_empty }
        end

        context 'with missing value' do
          subject { AlertLimit.delete(service_id, '50') }

          it { expect(subject).to be false }
        end

        context 'with nil value' do
          before { AlertLimit.save(service_id, 0) }

          subject { AlertLimit.delete(service_id, nil) }

          it { expect(subject).to be_falsey }
        end

        context 'with wrong value' do
          before { AlertLimit.save(service_id, 0) }

          subject { AlertLimit.delete(service_id, "fooo") }

          it { expect(subject).to be_falsey }
        end
      end

      describe '#save' do
        let(:alert_limit) { AlertLimit.new(service_id: service_id, value: value) }

        subject { alert_limit.save }

        it { expect(subject).to be true }
      end
    end
  end
end
