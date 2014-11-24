require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe LogRequestCubertStorage do

      describe '.store' do
        let(:enabled_provider_key) do
          bucket_id = Cubert::Client::Connection.new('http://localhost:8080').
            create_bucket
          storage.set(LogRequestCubertStorage.send(:bucket_id_key, 'foo'), bucket_id)
          'foo'
        end
        let(:enabled_service_id) do
          Service.save!(provider_key: enabled_provider_key, id: '7001')
          '7001'
        end
        let(:disabled_provider_key) { 'bar' }
        let(:disabled_service_id) do
          Service.save!(provider_key: disabled_provider_key, id: '7002')
          '7002'
        end

        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:enabled_service_log) { example_log(service_id: enabled_service_id) }
        let(:disabled_service_log) { example_log(service_id: disabled_service_id) }

        it 'runs when the usage flag is enabled' do
          doc_id = LogRequestCubertStorage.store(enabled_service_log)

          expect(LogRequestCubertStorage.get(enabled_provider_key, doc_id).
            body['service_id']).to eq(enabled_service_log[:service_id])
        end

        it "doesn't run when the usage flag is disabled" do
          doc_id = LogRequestCubertStorage.store(disabled_service_log)

          expect(doc_id).to be_nil
        end
      end

      private

      def example_log(params = {})
        default_params = {
          service_id: 1,
          application_id: 2,
          usage: {"metric_id_one" => 1},
          timestamp: Time.utc(2010, 9, 10, 17, 4),
          log: {'request' => 'req', 'response' => 'resp', 'code' => 200}
        }
        default_params.merge params
      end

    end
  end
end


