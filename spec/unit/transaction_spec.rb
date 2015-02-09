module ThreeScale
  module Backend
    describe Transaction do
      let(:transaction) { Transaction.new(service_id: 1000) }

      describe '#[]' do
        context 'with valid attribute' do
          subject { transaction[:service_id] }

          it { expect(subject).to be(1000) }
        end

        context 'with invalid attribute' do
          subject { transaction[:foo] }

          it { expect { subject }.to raise_error(NoMethodError) }
        end
      end

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
    end
  end
end
