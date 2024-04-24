resource 'Alert limits' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  get '/services/:service_id/alert_limits/' do
    parameter :service_id, 'Service ID', required: true
    let(:service_id) { '7575' }

    context 'when there are no alert limits' do
      example 'Getting alert limits', document: false do
        do_request

        expect(response_status).to eq(200)
        expect(response_json['alert_limits']).to eq([])
      end
    end

    context 'when there are alert limits' do
      before do
        ThreeScale::Backend::AlertLimit.save(service_id, 50)
        ThreeScale::Backend::AlertLimit.save(service_id, 100)
      end

      example_request 'Getting alert limits' do
        expected_values = [{ "service_id" => service_id, "value" => 50 },
                           { "service_id" => service_id, "value" => 100 }]

        expect(response_status).to eq(200)
        expect(response_json['alert_limits']).to eq(expected_values)
      end
    end
  end

  post '/services/:service_id/alert_limits/' do
    parameter :service_id, 'Service ID', required: true
    parameter :alert_limit, 'Limit value', required: true

    let(:service_id)  { '7575' }
    let(:raw_post) { params.to_json }

    context 'with allowed limit value' do
      let(:alert_limit) { { value: '50' } }

      example_request 'Add an alert limit' do
        expect(response_json['status']).to eq('created')
      end
    end

    context 'with no value for limit value' do
      let(:alert_limit) { { } }

      example 'Add an alert limit', document: false do
        do_request

        expect(response_status).to eq(400)
        expect(response_json['error']).to eq('alert limit is invalid')
      end
    end

    context 'with not allowed limit value' do
      let(:alert_limit) { { value: '3941412410' } }

      example 'Add an alert limit', document: false do
        do_request

        expect(response_status).to eq(400)
        expect(response_json['error']).to eq('alert limit is invalid')
      end
    end
  end

  delete '/services/:service_id/alert_limits/:value' do
    context 'with a missing alert limit' do
      example 'Delete an alert limit', document: false do
        do_request

        expect(response_status).to eq(404)
        expect(response_json['status']).to eq('not_found')
      end
    end

    context 'with a valid alert limit' do
      before { ThreeScale::Backend::AlertLimit.save(service_id, 50) }

      parameter :service_id, 'Service ID', required: true
      parameter :value, 'Limit value', required: true

      let(:service_id) { '7575' }
      let(:value)      { '50' }

      example_request 'Delete an alert limit' do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end
end
