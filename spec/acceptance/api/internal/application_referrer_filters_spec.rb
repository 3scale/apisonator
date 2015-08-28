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
      example 'Getting application keys' do
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

  post '/services/:service_id/applications/:app_id/referrer_filters' do
    parameter :referrer_filter, 'Referrer filter to create', required: true

    let(:service_id) { '7575' }
    let(:app_id) { '100' }
    let(:referrer_filter) { 'baz' }
    let(:raw_post) { params.to_json }

    example_request 'Create a referrer filter' do
      status.should == 201
      response_json['status'].should == 'created'

      @app.referrer_filters.should == ['baz']
    end

    example 'Try updating Service with invalid data' do
      do_request referrer_filter: ''

      status.should == 400
      response_json['error'].should =~ /referrer filter can't be blank/
    end
  end

  delete '/services/:service_id/applications/:app_id/referrer_filters/:filter' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    let(:service_id) { '7575' }
    let(:app_id)     { '100' }
    let(:filter)     { 'doopah' }

    context 'when there are no referrer filters' do
      example_request 'Trying to delete a filter' do
        do_request

        expect(response_status).to eq(200)
      end
    end

    context 'when there are referrer filters' do
      before do
        @app.create_referrer_filter('doopah')
      end

      example_request 'Deleting a filter' do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end
end

