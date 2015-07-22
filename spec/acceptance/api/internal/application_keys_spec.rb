require_relative '../../acceptance_spec_helper'

resource 'Application keys' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  before do
    @app = ThreeScale::Backend::Application.save(service_id: '7575', id: '100',
                                                 plan_id: '9', plan_name: 'plan',
                                                 state: :active,
                                                 redirect_url: 'https://3scale.net')
  end

  get '/services/:service_id/applications/:app_id/keys/' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    let(:service_id) { '7575' }
    let(:app_id)     { '100' }

    context 'when there are no application keys' do
      example 'Getting application keys', document: false do
        do_request

        expect(response_status).to eq(200)
        expect(response_json['application_keys']).to eq([])
      end
    end

    context 'when there are application keys' do
      before do
        @app.create_key("foo")
        @app.create_key("bar")
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

    let(:service_id) { '7575' }
    let(:app_id)     { '100' }
    let(:raw_post)   { params.to_json }

    context 'with application key value' do
      let(:application_key) { { value: 'foo' } }

      example_request 'Add an application key' do
        expect(response_status).to eq(201)
        expect(response_json['status']).to eq('created')
      end
    end

    context 'with no value for application key' do
      let(:application_key) { { } }

      example 'Add an application key', document: false do
        do_request

        expect(response_status).to eq(201)
        expect(response_json['status']).to eq('created')
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

    context 'with a valid application key' do
      before { @app.create_key("foo") }

      parameter :service_id, 'Service ID', required: true
      parameter :app_id, 'Application ID', required: true
      parameter :value, 'Application key value', required: true

      let(:service_id)     { '7575' }
      let(:app_id)         { '100' }
      let(:value)          { 'foo' }

      example_request 'Delete an application key' do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end

end
