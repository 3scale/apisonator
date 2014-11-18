require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe LogRequestCubertStorage do

      describe '.store' do
        let(:doc_id) { LogRequestCubertStorage.store(foo: 'bar').id }

        it 'stores data' do
          expect(LogRequestCubertStorage.get(doc_id).body['foo']).to eq('bar')
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


