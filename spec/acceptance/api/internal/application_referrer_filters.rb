require_relative '../../acceptance_spec_helper'

resource 'Application keys' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  before do
    @app = ThreeScale::Backend::Application.save(
      service_id: '7575', id: '100', plan_id: '9', plan_name: 'plan',
      state: :active, redirect_url: 'https://3scale.net')
  end

  get '/services/:service_id/applications/:app_id/referrer_filters' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    let(:service_id) { '7575' }
    let(:app_id)     { '100' }

    context 'when there are no referrer filters' do
      example 'Getting application keys', document: false do
        do_request

        expect(response_status).to eq(200)
        expect(response_json['referrer_filters']).to eq([])
      end
    end

    context 'when there are referrer filters' do
      before do
        @app.create_referrer_filter('foo')
        @app.create_referrer_filter('bar')
      end

      example_request 'Getting referrer filters' do
        expected_values = ['bar', 'foo']

        expect(response_status).to eq(200)
        expect(response_json['referrer_filters']).to match_array(expected_values)
      end
    end
  end

end

