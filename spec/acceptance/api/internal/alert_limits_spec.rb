describe 'Alert limits' do
  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'
  end

  context '/services/:service_id/alert_limits/' do
    context 'GET' do
      let(:service_id) { '7575' }

      context 'when there are no alert limits' do
        it 'Getting alert limits' do
          get "/services/#{service_id}/alert_limits/"

          expect(response_status).to eq(200)
          expect(response_json['alert_limits']).to eq([])
        end
      end

      context 'when there are alert limits' do
        before do
          ThreeScale::Backend::AlertLimit.save(service_id, 50)
          ThreeScale::Backend::AlertLimit.save(service_id, 100)
        end

        it 'Getting alert limits' do
          expected_values = [{ "service_id" => service_id, "value" => 50 },
                             { "service_id" => service_id, "value" => 100 }]

          get "/services/#{service_id}/alert_limits/"

          expect(response_status).to eq(200)
          expect(response_json['alert_limits']).to eq(expected_values)
        end
      end
    end

    context 'POST' do
      let(:service_id)  { '7575' }

      context 'with allowed limit value' do
        let(:alert_limit) { { value: '50' } }

        it 'Add an alert limit' do
          post "/services/#{service_id}/alert_limits/", { alert_limit: }.to_json

          expect(response_json['status']).to eq('created')
        end
      end

      context 'with no value for limit value' do
        let(:alert_limit) { { } }

        it 'Add an alert limit' do
          post "/services/#{service_id}/alert_limits/", { alert_limit: }.to_json

          expect(response_status).to eq(400)
          expect(response_json['error']).to eq('alert limit is invalid')
        end
      end

      context 'with not allowed limit value' do
        let(:alert_limit) { { value: '3941412410' } }

        it 'Add an alert limit' do
          post "/services/#{service_id}/alert_limits/", { alert_limit: }.to_json

          expect(response_status).to eq(400)
          expect(response_json['error']).to eq('alert limit is invalid')
        end
      end
    end
  end

  context 'DELETE /services/:service_id/alert_limits/:value' do
    let(:service_id) { '7575' }
    let(:value)      { '50' }

    before do
      ThreeScale::Backend::AlertLimit.save(service_id, value)
    end

    context 'with an invalid alert limit' do
      it 'Delete an alert limit' do
        invalid_key = 'invalid'

        delete "/services/#{service_id}/alert_limits/#{invalid_key}"

        expect(response_status).to eq(404)
        expect(response_json['status']).to eq('not_found')
      end
    end

    context 'with a valid alert limit' do
      it 'Delete an alert limit' do
        delete "/services/#{service_id}/alert_limits/#{value}"

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end
end
