module ThreeScale
  module Backend
    describe Transaction do
      let(:transaction) { Transaction.new(service_id: 1000) }

      describe '#timestamp=' do
        context 'with nil as a parameter' do
          before { transaction.timestamp = nil }
          subject { transaction.timestamp }

          it { expect(subject.to_i).to eq(Time.now.getutc.to_i) }
        end

        context 'with time object as a parameter' do
          let(:time_value) { Time.now - 3600 }
          before { transaction.timestamp = time_value }
          subject { transaction.timestamp }

          it { expect(subject).to eq(time_value) }
        end

        context 'with valid time string as a parameter' do
          let(:original_time) { Time.now.getutc - 3600 }
          let(:time_value) { original_time.to_s }
          before { transaction.timestamp = time_value }
          subject { transaction.timestamp }

          it { expect(subject.to_i).to eq(original_time.to_i) }
        end

        context 'with invalid time string as a parameter' do
        end
      end

      describe '#ensure_on_time!' do
        context 'when transaction timestamp is older than 1 day' do
          let(:attrs) { { timestamp: Time.now - (48 * 3600) } }
          subject { Transaction.new(attrs).ensure_on_time! }

          # Temporary change: For now, we want to send an Airbrake notification
          # and return true.
          it { expect(subject).to be_true }

          # Previous code to restore when we decide to limit the timestamps:
          # it { expect { subject }.to raise_error(ReportTimestampNotWithinRange) }
        end

        context 'when transaction timestamp is newer than 1 day' do
          let(:attrs) { { timestamp: Time.now - 3600 } }
          subject { Transaction.new(attrs).ensure_on_time! }

          it { expect(subject).to be_true }
        end
      end
    end
  end
end
