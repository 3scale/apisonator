module ThreeScale
  module Backend
    module Transactor
      describe ReportJob do
        include TestHelpers::Sequences

        before { ThreeScale::Backend::Worker.new }

        describe '.perform' do
          let(:service_id)       { 1000 }
          let(:raw_transactions) { [{}] }
          let(:enqueue_time)     { Time.now.to_f }
          let(:context_info)     { {} }

          context 'when a backend exception is raised' do
            before do
              expect(ReportJob)
                  .to receive(:parse_transactions)
                          .and_raise(Backend::ServiceIdInvalid.new(service_id))
            end

            it 'rescues the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time, context_info)
              }.to_not raise_error
            end
          end

          context 'when a core exception is raised' do
            before do
              expect(ReportJob)
                  .to receive(:parse_transactions)
                          .and_raise(Backend::UserKeyInvalid.new('some_user_key'))
            end

            it 'rescues the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time, context_info)
              }.to_not raise_error
            end
          end

          context 'when a generic exception is raised' do
            before do
              expect(ReportJob).to receive(:parse_transactions).and_raise(Exception.new)
            end

            it 'raises the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time, context_info)
              }.to raise_error(Exception)
            end
          end
        end
      end
    end
  end
end
