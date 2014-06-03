require_relative '../spec_helper'

module ThreeScale
  module Backend
    module Transactor
      describe ReportJob do
        before { ThreeScale::Backend::Worker.new }

        describe '.perform' do
          let(:service_id)       { 6 }
          let(:raw_transactions) { [{}] }
          let(:enqueue_time)     { Time.now.to_f }

          context 'when a backend exception is raised' do
            before do
              ReportJob.should_receive(:parse_transactions) {
                raise ThreeScale::Backend::ServiceIdInvalid.new(service_id)
              }
            end

            it 'rescues the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time)
              }.to_not raise_error
            end
          end

          context 'when a core exception is raised' do
            before do
              ReportJob.should_receive(:parse_transactions) {
                raise ThreeScale::Core::ServiceRequiresRegisteredUser.new(service_id)
              }
            end

            it 'rescues the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time)
              }.to_not raise_error
            end
          end

          context 'when a generic exception is raised' do
            before do
              ReportJob.should_receive(:parse_transactions) {
                raise Exception.new
              }
            end

            it 'raises the exception' do
              expect {
                ReportJob.perform(service_id, raw_transactions, enqueue_time)
              }.to raise_error(Exception)
            end
          end
        end
      end
    end
  end
end
