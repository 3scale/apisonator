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

        context 'with invalid timestamp string as a parameter' do
          let(:current_time) { Time.now }
          let(:invalid_timestamp) { 'i_am_not_a_timestamp' }
          before do
            Timecop.freeze(current_time) do
              transaction.timestamp = invalid_timestamp
            end
          end

          it 'sets the timestamp to the current time' do
            expect(transaction.timestamp).to eq(current_time)
          end
        end
      end

      describe '#ensure_on_time!' do
        context 'when transaction timestamp is the current time' do
          let(:current_time) { Time.now }
          let(:transaction_attrs) { { timestamp: current_time } }

          it 'does not raise' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }.to_not raise_error
            end
          end
        end

        context 'when transaction timestamp is not now, but is within the allowed limits' do
          let(:past_limit) { described_class.const_get(:REPORT_DEADLINE_PAST) }
          let(:current_time) { Time.now }
          let(:transaction_attrs) { { timestamp: current_time - past_limit + 1 } }

          it 'does not raise' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }.to_not raise_error
            end
          end
        end

        context 'when transaction timestamp is not specified explicitly' do
          # The transaction timestamp is assigned the current time by default,
          # so it is within the allowed limits
          it 'does not raise' do
            expect { Transaction.new.ensure_on_time! }.to_not raise_error
          end
        end

        context 'when transaction timestamp is older than allowed' do
          let(:limit) { described_class.const_get(:REPORT_DEADLINE_PAST) }
          let(:current_time) { Time.now }
          let(:transaction_attrs) { { timestamp: current_time - limit - 1 } }

          it 'raises TransactionTimestampTooOld' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }
                  .to raise_error(TransactionTimestampTooOld)
            end
          end

          it 'raises TransactionTimestampNotWithinRange' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }
                  .to raise_error(TransactionTimestampNotWithinRange)
            end
          end
        end

        context 'when transaction timestamp is newer than allowed' do
          let(:limit) { described_class.const_get(:REPORT_DEADLINE_FUTURE) }
          let(:current_time) { Time.now }
          let(:transaction_attrs) { { timestamp: current_time + limit + 1 } }

          it 'raises TransactionTimestampTooNew' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }
                  .to raise_error(TransactionTimestampTooNew)
            end
          end

          it 'raises TransactionTimestampNotWithinRange' do
            Timecop.freeze(current_time) do
              expect { Transaction.new(transaction_attrs).ensure_on_time! }
                  .to raise_error(TransactionTimestampNotWithinRange)
            end
          end
        end
      end
    end
  end
end
