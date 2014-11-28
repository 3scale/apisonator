require_relative '../spec_helper'

module ThreeScale
  module Backend

    describe LogRequestCubertStorage do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:enabled_service) { LogRequestCubertStorage.enable_service('7001'); '7001' }
      let(:disabled_service) { '7002' }

      describe '.store' do
        let(:enabled_service_log) { example_log(service_id: enabled_service) }
        let(:disabled_service_log) { example_log(service_id: disabled_service) }

        context 'global request log storage enabled' do
          before { LogRequestCubertStorage.global_enable }

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
          before { LogRequestCubertStorage.global_disable }

          it "doesn't store logs" do
            doc_id = LogRequestCubertStorage.store(enabled_service_log)

            expect(doc_id).to be_nil
          end
        end
      end

      describe '.disable_service' do
        it 'remove the cubert bucket info from Redis' do
          LogRequestCubertStorage.disable_service enabled_service

          expect(LogRequestCubertStorage.send(:bucket, enabled_service)).
            to be_nil
        end
      end

      it 'reuses the connection' do
        old_id = LogRequestCubertStorage.send(:connection).object_id
        new_id = LogRequestCubertStorage.send(:connection).object_id
        expect(old_id).to eq(new_id)
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


