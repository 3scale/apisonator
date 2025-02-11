describe 'Application Referrer Filters' do
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

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'
  end

  context '/services/:service_id/applications/:app_id/referrer_filters' do
    context 'GET' do
      context 'with an invalid application id' do
        let(:app_id) { 400 }

        it 'Getting application keys' do
          get "/services/#{service_id}/applications/#{app_id}/referrer_filters"

          expect(response_status).to eq(404)
          expect(response_json['error']).to eq("application not found")
        end
      end

      context 'when there are no referrer filters' do
        it 'Getting application keys' do
          get "/services/#{service_id}/applications/#{app_id}/referrer_filters"

          expect(response_status).to eq(200)
          expect(response_json['referrer_filters']).to eq([])
        end
      end

      context 'when there are referrer filters' do
        before do
          example_app.create_referrer_filter('foo')
          example_app.create_referrer_filter('bar')
        end

        it 'Getting referrer filters' do
          get "/services/#{service_id}/applications/#{app_id}/referrer_filters"

          expected_values = ['bar', 'foo']

          expect(response_status).to eq(200)
          expect(response_json['referrer_filters']).to match_array(expected_values)
        end
      end
    end

    context 'POST' do
      let(:referrer_filter) { 'baz' }

      it 'Create a referrer filter' do
        post "/services/#{service_id}/applications/#{app_id}/referrer_filters", { referrer_filter: }.to_json

        expect(response_status).to eq(201)
        expect(response_json['status']).to eq("created")

        expect(example_app.referrer_filters).to eq ['baz']
      end

      it 'Try updating a referrer filter with invalid application id' do
        app_id = 400

        post "/services/#{service_id}/applications/#{app_id}/referrer_filters", { referrer_filter: }.to_json

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end

      it 'Try updating a referrer filter with invalid data' do
        referrer_filter = ''

        post "/services/#{service_id}/applications/#{app_id}/referrer_filters", { referrer_filter: }.to_json

        expect(response_status).to eq(400)
        expect(response_json['error']).to eq("referrer filter can't be blank")
      end
    end
  end

  describe 'DELETE /services/:service_id/applications/:app_id/referrer_filters/:filter' do
    let(:filter)     { 'doopah' }

    context 'when there are no referrer filters' do
      it 'Trying to delete a filter' do
        delete "/services/#{service_id}/applications/#{app_id}/referrer_filters/#{filter}"

        expect(response_status).to eq(200)
      end
    end

    context 'when there is a filter with special chars' do
      let(:value) { 'chrome-extension://fdmmgilgnpjigdojojpjoooidkmcomcm' }
      before do
        example_app.create_referrer_filter(value)
      end

      it 'Deleting a filter with special chars' do
        filter = Base64.urlsafe_encode64(value)

        delete "/services/#{service_id}/applications/#{app_id}/referrer_filters/#{filter}"

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end

    context 'when there are referrer filters' do
      before do
        example_app.create_referrer_filter('doopah')
      end

      it 'Deleting a filter' do
        delete "/services/#{service_id}/applications/#{app_id}/referrer_filters/#{filter}"

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
      end
    end
  end
end
