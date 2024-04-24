resource 'Application Referrer Filters' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:service_id) { '7575' }
  let(:app_id)     { '100' }

  let!(:example_app) do
    ThreeScale::Backend::Application.save(service_id: service_id,
                                          id: '100',
                                          plan_id: '9',
                                          plan_name: 'plan',
                                          state: :active,
                                          redirect_url: 'https://3scale.net')
  end

  get '/services/:service_id/applications/:app_id/referrer_filters' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true


    context 'with an invalid application id' do
      example 'Getting application keys' do
        do_request(app_id: 400)

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end
    end

    context 'when there are no referrer filters' do
      example_request 'Getting application keys' do
        expect(response_status).to eq(200)
        expect(response_json['referrer_filters']).to eq([])
      end
    end

    context 'when there are referrer filters' do
      before do
        example_app.create_referrer_filter('foo')
        example_app.create_referrer_filter('bar')
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

    let(:referrer_filter) { 'baz' }
    let(:raw_post) { params.to_json }

    example_request 'Create a referrer filter' do
      expect(response_status).to eq(201)
      expect(response_json['status']).to eq("created")

      expect(example_app.referrer_filters).to eq ['baz']
    end

    example 'Try updating a referrer filter with invalid application id' do
      do_request app_id: '400'

      expect(response_status).to eq(404)
      expect(response_json['error']).to eq("application not found")
    end


    example 'Try updating a referrer filter with invalid data' do
      do_request referrer_filter: ''

      expect(response_status).to eq(400)
      expect(response_json['error']).to eq("referrer filter can't be blank")
    end
  end

  delete '/services/:service_id/applications/:app_id/referrer_filters/:filter' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    let(:filter)     { 'doopah' }

    context 'when there are no referrer filters' do
      example_request 'Trying to delete a filter' do
        expect(response_status).to eq(200)
      end
    end

    context 'when there is a filter with special chars' do
      let(:value) { 'chrome-extension://fdmmgilgnpjigdojojpjoooidkmcomcm' }
      before do
        example_app.create_referrer_filter(value)
      end

      example 'Deleting a filter with special chars' do
        do_request filter: Base64.urlsafe_encode64(value)

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end

    context 'when there are referrer filters' do
      before do
        example_app.create_referrer_filter('doopah')
      end

      example_request 'Deleting a filter' do
        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end
end
