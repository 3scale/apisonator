require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module RequestLogs
      describe Storage do
        let(:service_id) { 1 }
        let(:app_id) { 2 }

        describe 'complete transactions' do
          let(:app_id_two){ 4 }
          let(:log1) { example_log }
          let(:log2) { example_log({ application_id: app_id_two }) }
          let(:list_service) { described_class.list_by_service(service_id) }
          let(:list_app) { described_class.list_by_application(service_id, app_id) }

          before { described_class.store_all([log1, log2]) }

          describe 'getting logs' do
            it 'returns proper transactions given the service ID' do
              expect(described_class.count_by_service(service_id)).to eq(2)
              expect(list_service.size).to eq(2)
              expect(list_service[1]).to eq(log1)
              expect(list_service[0]).to eq(log2)
            end

            it 'returns empty list given a different service ID' do
              expect(described_class.count_by_service(5)).to eq(0)
              expect(described_class.list_by_service(5).size).to eq(0)
            end

            it 'filters out transactions by the service and app IDs' do
              expect(described_class.count_by_application(service_id, app_id)).
                to eq(1)
              expect(list_app.size).to eq(1)
              expect(list_app[0]).to eq(log1)
            end
          end

          describe 'deleting logs' do
            it 'given application IDs deletes only from per-app list' do
              described_class.delete_by_application(service_id, app_id_two)

              expect(described_class.list_by_application(service_id, app_id_two).
                     size).to eq(0)
              expect(described_class.list_by_service(service_id).size).to eq(2)
            end

            it 'given another service ID doesn\'t delete anything' do
              described_class.delete_by_service(5)

              expect(described_class.list_by_service(service_id).size).to eq(2)
            end

            it 'given the service ID deletes only from per-service list' do
              described_class.delete_by_service(service_id)

              expect(described_class.list_by_service(service_id).size).to eq(0)
              expect(described_class.list_by_application(service_id, app_id).
                     size).to eq(1)
            end
          end
        end

        describe 'storing logs' do
          before do
            stub_const("RequestLogs::Storage::LIMIT_PER_SERVICE", 2)
            stub_const("RequestLogs::Storage::LIMIT_PER_APP", 1)
            (described_class::LIMIT_PER_SERVICE + described_class::LIMIT_PER_APP).
              times { described_class.store(example_log) }
          end

          it 'respects the limits of the lists' do
            expect(described_class.count_by_service(service_id)).
              to eq(described_class::LIMIT_PER_SERVICE)
            expect(described_class.count_by_application(service_id, app_id)).
              to eq(described_class::LIMIT_PER_APP)
          end
        end

        private

        def example_log(params = {})
          default_params = {
            service_id: service_id,
            application_id: app_id,
            usage: {"metric_id_one" => 1},
            timestamp: Time.utc(2010, 9, 10, 17, 4),
            log: {'request' => 'req', 'response' => 'resp', 'code' => 200}
          }
          default_params.merge params
        end

      end
    end
  end
end
