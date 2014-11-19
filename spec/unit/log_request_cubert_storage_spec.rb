require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe LogRequestCubertStorage do

      describe '.store' do
        let(:storage) { ThreeScale::Backend::Storage.instance }
        let(:provider_enabled) do
          bucket_id = Cubert::Client::Connection.new('http://localhost:8080').
            create_bucket
          storage.set(LogRequestCubertStorage.send(:bucket_id_key, 'foo'), bucket_id)
          'foo'
        end
        let(:provider_disabled) { 'bar' }
        let(:log) { example_log }

        it 'runs when the usage flag is enabled' do
          doc_id = LogRequestCubertStorage.store(provider_enabled, log)

          expect(LogRequestCubertStorage.get(provider_enabled, doc_id).body['service_id']).
            to eq(log[:service_id])
        end

        it "doesn't run when the usage flag is disabled" do
          doc_id = LogRequestCubertStorage.store(provider_disabled, log)

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


