resource 'Application keys' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:service_id)     { '7575' }
  let(:app_id)         { '100' }
  let(:invalid_app_id) { '400' }

  let!(:example_app) do
    ThreeScale::Backend::Application.save(service_id: service_id,
                                          id: app_id,
                                          plan_id: '9',
                                          plan_name: 'plan',
                                          state: :active,
                                          redirect_url: 'https://3scale.net')
  end

  get '/services/:service_id/applications/:app_id/keys/' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    context 'with an invalid application id' do
      example 'Getting application keys', document: false do
        do_request(app_id: invalid_app_id)

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end
    end

    context 'when there are no application keys' do
      example 'Getting application keys', document: false do
        do_request

        expect(response_status).to eq(200)
        expect(response_json['application_keys']).to eq([])
      end
    end

    context 'when there are application keys' do
      before do
        example_app.create_key("foo")
        example_app.create_key("bar")
      end

      example_request 'Getting application keys' do
        expected_values = [
          { "service_id" => service_id, "app_id" => app_id, "value" => "bar" },
          { "service_id" => service_id, "app_id" => app_id, "value" => "foo" },
        ]

        expect(response_status).to eq(200)
        expect(response_json['application_keys']).to match_array(expected_values)
      end
    end
  end

  post '/services/:service_id/applications/:app_id/keys/' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true
    parameter :application_key, 'Application key value', required: false

    let(:raw_post)   { params.to_json }

    context 'with an invalid application id' do
      example 'Trying to create an application key', document: false do
        do_request(app_id: invalid_app_id)

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end
    end

    context 'with application key value' do
      let(:application_key) { { value: 'foo' } }

      example_request 'Add an application key' do
        expect(response_status).to eq(201)
        expect(response_json['status']).to eq('created')
      end
    end

    context 'with no value for application key' do
      before { expect(SecureRandom).to receive(:hex).and_return('random') }

      let(:application_key) { { } }

      example 'Add an application key', document: false do
        do_request

        expect(response_status).to eq(201)
        expect(response_json['status']).to eq('created')
        expect(example_app.has_key?('random')).to be true
      end
    end
  end

  delete '/services/:service_id/applications/:app_id/keys/:value' do
    context 'with a missing application key' do
      example 'Delete an application key', document: false do
        do_request

        expect(response_status).to eq(404)
        expect(response_json['status']).to eq('not_found')
      end
    end

    context 'with an invalid application id' do
      example 'Trying to delete an application key', document: false do
        do_request(app_id: invalid_app_id)

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end
    end

    context 'with a valid application key' do
      before { example_app.create_key("foo") }

      parameter :service_id, 'Service ID', required: true
      parameter :app_id, 'Application ID', required: true
      parameter :value, 'Application key value', required: true

      let(:value)          { 'foo' }

      example_request 'Delete an application key' do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
        expect(example_app.has_key?("foo")).to be false
      end
    end
  end

end
