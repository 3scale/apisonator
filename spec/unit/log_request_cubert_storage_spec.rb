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

        it 'runs when the service usage flag is enabled' do
          doc_id = LogRequestCubertStorage.store(enabled_service_log)

          expect(LogRequestCubertStorage.get(enabled_service, doc_id).
            body['service_id']).to eq(enabled_service_log[:service_id])
        end

        it "doesn't run when the service usage flag is disabled" do
          doc_id = LogRequestCubertStorage.store(disabled_service_log)

          expect(doc_id).to be_nil
        end
      end

    end
  end
end


