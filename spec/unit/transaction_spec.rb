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

      describe '#extract_response_code' do
        before { transaction.response_code = response_code }

        shared_examples 'transaction_with_invalid_response_code' do |response_code|
          let(:response_code) { response_code }

          it 'returns false' do
            expect(transaction.extract_response_code).to be false
          end
        end

        context 'when response code is a string' do
          context 'and it has 3 characters that represent a positive number' do
            let(:response_code) { '400' }

            it 'returns the parsed response code' do
              expect(transaction.extract_response_code).to eq response_code.to_i
            end
          end

          context 'and it has 3 characters that represent a negative number' do
            include_examples 'transaction_with_invalid_response_code', '-40'
          end

          context 'and it represents a negative number of 3 digits' do
            include_examples 'transaction_with_invalid_response_code', '-400'
          end

          context 'and it has less than 3 characters' do
            include_examples 'transaction_with_invalid_response_code', '40'
          end

          context 'and it has more than 3 characters' do
            include_examples 'transaction_with_invalid_response_code', '4000'
          end

          context 'and it has 3 characters that do not represent a number' do
            include_examples 'transaction_with_invalid_response_code', 'a40'
          end
        end

        context 'when response code is an integer' do
          context 'and it has 3 digits' do
            let(:response_code) { 400 }

            it 'returns the response code' do
              expect(transaction.extract_response_code).to eq response_code
            end
          end

          context 'and it has less than 3 digits' do
            include_examples 'transaction_with_invalid_response_code', 40
          end

          context 'and it has more than 3 digits' do
            include_examples 'transaction_with_invalid_response_code', 4000
          end

          context 'and it is negative' do
            include_examples 'transaction_with_invalid_response_code', -400
          end
        end
      end

      describe '#ensure_on_time!' do
        context 'when transaction timestamp is older than 1 day' do
          let(:attrs) { { timestamp: Time.now - (48 * 3600) } }
          subject { Transaction.new(attrs).ensure_on_time! }

          # Temporary change: For now, we want to send an Airbrake notification
          # and return true.
          it { expect(subject).to be true }

          # Previous code to restore when we decide to limit the timestamps:
          # it { expect { subject }.to raise_error(ReportTimestampNotWithinRange) }
        end

        context 'when transaction timestamp is newer than 1 day' do
          let(:attrs) { { timestamp: Time.now - 3600 } }
          subject { Transaction.new(attrs).ensure_on_time! }

          it { expect(subject).to be true }
        end
      end
    end
  end
end
