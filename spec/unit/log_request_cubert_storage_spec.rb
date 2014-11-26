require_relative '../spec_helper'

module ThreeScale
  module Backend

    describe LogRequestCubertStorage do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:enabled_service) do
        bucket_id = Cubert::Client::Connection.new('http://localhost:8080').
          create_bucket
        storage.set(LogRequestCubertStorage.send(:bucket_id_key, '7001'), bucket_id)
        '7001'
      end
      let(:disabled_service) { '7002' }

      describe '.store' do
        let(:enabled_service_log) { example_log(service_id: enabled_service) }
        let(:disabled_service_log) { example_log(service_id: disabled_service) }

        context 'global request log storage enabled' do
          before { storage.set(LogRequestCubertStorage.send(:global_lock_key), true) }

          it 'runs when the service usage flag is enabled' do
            doc_id = LogRequestCubertStorage.store(enabled_service_log)

            expect(cubert_get(enabled_service, doc_id).body['service_id']).
              to eq(enabled_service_log[:service_id])
          end

          it "doesn't run when the service usage flag is disabled" do
            doc_id = LogRequestCubertStorage.store(disabled_service_log)

            expect(doc_id).to be_nil
          end
        end

        context 'global request log storage disabled' do
          it "doesn't store logs" do
            doc_id = LogRequestCubertStorage.store(enabled_service_log)

            expect(doc_id).to be_nil
          end
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

      def cubert_get(service_id, document_id)
        Cubert::Client::Connection.new('http://localhost:8080').get_document(
          document_id,
          LogRequestCubertStorage.send(:bucket, service_id),
          LogRequestCubertStorage.send(:collection)
        )
      end
    end

  end
end


