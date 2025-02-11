describe 'Application keys' do
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

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'
  end

  context '/services/:service_id/applications/:app_id/keys/' do
    context 'GET' do
      context 'with an invalid application id' do
        it 'Getting application keys' do
          get "/services/#{service_id}/applications/#{invalid_app_id}/keys/"

          expect(response_status).to eq(404)
          expect(response_json['error']).to eq("application not found")
        end
      end

      context 'when there are no application keys' do
        it 'Getting application keys' do
          get "/services/#{service_id}/applications/#{app_id}/keys/"

          expect(response_status).to eq(200)
          expect(response_json['application_keys']).to eq([])
        end
      end

      context 'when there are application keys' do
        before do
          example_app.create_key("foo")
          example_app.create_key("bar")
        end

        it 'Getting application keys' do
          get "/services/#{service_id}/applications/#{app_id}/keys/"

          expected_values = [
            { "service_id" => service_id, "app_id" => app_id, "value" => "bar" },
            { "service_id" => service_id, "app_id" => app_id, "value" => "foo" },
          ]

          expect(response_status).to eq(200)
          expect(response_json['application_keys']).to match_array(expected_values)
        end
      end
    end

    context 'POST' do
      context 'with an invalid application id' do
        it 'Trying to create an application key' do
          post "/services/#{service_id}/applications/#{invalid_app_id}/keys/"

          expect(response_status).to eq(404)
          expect(response_json['error']).to eq("application not found")
        end
      end

      context 'with application key value' do
        let(:application_key) { { value: 'foo' } }

        it 'Add an application key' do
          post "/services/#{service_id}/applications/#{app_id}/keys/", { application_key: }.to_json

          expect(response_status).to eq(201)
          expect(response_json['status']).to eq('created')
        end
      end

      context 'with no value for application key' do
        before { expect(SecureRandom).to receive(:hex).and_return('random') }

        let(:application_key) { { } }

        it 'Add an application key' do
          post "/services/#{service_id}/applications/#{app_id}/keys/", { application_key: }.to_json

          expect(response_status).to eq(201)
          expect(response_json['status']).to eq('created')
          expect(example_app.has_key?('random')).to be true
        end
      end
    end
  end

  context 'DELETE /services/:service_id/applications/:app_id/keys/:value' do
    let(:value)          { "foo" }

    before do
      example_app.create_key(value)
    end

    context 'with an invalid application key' do
      it 'Delete an application key' do
        invalid_key = 'invalid'

        delete "/services/#{service_id}/applications/#{app_id}/keys/#{invalid_key}"

        expect(response_status).to eq(404)
        expect(response_json['status']).to eq('not_found')
      end
    end

    context 'with an invalid application id' do
      it 'Trying to delete an application key' do
        delete "/services/#{service_id}/applications/#{invalid_app_id}/keys/#{value}"

        expect(response_status).to eq(404)
        expect(response_json['error']).to eq("application not found")
      end
    end

    context 'with a valid application key' do
      it 'Delete an application key' do
        delete "/services/#{service_id}/applications/#{app_id}/keys/#{value}"

        expect(response_status).to eq(200)
        expect(response_json['status']).to eq('deleted')
        expect(example_app.has_key?("foo")).to be false
      end
    end
  end

end
