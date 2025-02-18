describe 'Applications (prefix: /services/:service_id/applications)' do

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'

    ThreeScale::Backend::Application.delete('7575', '100') rescue nil
    ThreeScale::Backend::Application.save(service_id: '7575',
                                          id: '100',
                                          plan_id: '9',
                                          plan_name: 'plan',
                                          state: :active,
                                          redirect_url: 'https://3scale.net')
  end

  context '/services/:service_id/applications/:id' do
    context 'GET' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:service_id_non_existent) { service_id.to_i.succ.to_s }
      let(:id_non_existent) { id.to_i.succ.to_s }

      it 'Get Application by ID' do
        get "/services/#{service_id}/applications/#{id}"

        expect(response_json['application']['id']).to eq id
        expect(response_json['application']['service_id']).to eq service_id
        expect(status).to eq 200
      end

      it 'Try to get an Application by non-existent ID' do
        get "/services/#{service_id}/applications/#{id_non_existent}"

        expect(status).to eq 404
        expect(response_json['error']).to match /application not found/i
      end

      it 'Try to get an Application by non-existent service ID' do
        get "/services/#{service_id_non_existent}/applications/#{id}"

        expect(status).to eq 404
        expect(response_json['error']).to match /application not found/i
      end
    end

    context 'POST' do
      let(:service_id) { '7575' }
      let(:id) { '200' }
      let(:plan_id) { '100' }
      let(:plan_name) { 'some_plan' }
      let(:state) { :active }
      let(:redirect_url) { 'https://3scale.net' }
      let(:application) do
        {
          service_id: service_id,
          id: id,
          plan_id: plan_id,
          plan_name: plan_name,
          state: state,
          redirect_url: redirect_url
        }
      end

      it 'Create an Application' do
        post "/services/#{service_id}/applications/#{id}", { application: }.to_json

        expect(status).to eq 201
        expect(response_json['status']).to eq 'created'

        app = ThreeScale::Backend::Application.load(service_id, id)
        expect(app.to_hash).to eq application
      end

      it 'Create an Application with extra params that should be ignored' do
        application_params = application.merge(some_param: 'some_val')

        post "/services/#{service_id}/applications/#{id}", { application: application_params }.to_json

        expect(status).to eq 201
        expect(response_json['status']).to eq 'created'

        app = ThreeScale::Backend::Application.load(service_id, id)
        expect(app).not_to be_nil
        expect(app).not_to respond_to :some_param
        # The returned data should not contain *some_param* attribute
        expect(app.to_hash).to eq application
      end

      context 'with an application that has no state' do
        let (:state) { nil }

        it 'Trying to create the application' do
          post "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 400
          expect(response_json['status']).to eq 'bad_request'
          expect(response_json['error']).to match /has no state/i
        end
      end

      context 'with a disabled service' do
        let (:service_id) { '6666' }

        it 'Trying to create/update the application' do
          ThreeScale::Backend::Service.save! id: service_id, provider_key: 'bar', state: :suspended

          post "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 201
          expect(response_json['status']).to eq 'created'
        end
      end
    end

    context 'PUT' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:plan_id) { '101' }
      let(:plan_name) { 'some_other_plan' }
      let(:state) { :active }
      let(:redirect_url) { 'https://3scale.net' }
      let(:application) do
        {
          service_id: service_id,
          id: id,
          plan_id: plan_id,
          plan_name: plan_name,
          state: state,
          redirect_url: redirect_url
        }
      end

      context 'with an application that exists' do
        it 'updating the application' do
          put "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 200
          expect(response_json['status']).to eq 'modified'

          app = ThreeScale::Backend::Application.load(service_id, id)
          expect(app.to_hash).to eq application
        end

        it 'updating the application with extra params that should be ignored' do
          application_param = application.merge(some_param: 'some_val')

          put "/services/#{service_id}/applications/#{id}", { application: application_param }.to_json

          expect(status).to eq 200
          expect(response_json['status']).to eq 'modified'

          app = ThreeScale::Backend::Application.load(service_id, id)
          expect(app).not_to be_nil
          expect(app).not_to respond_to :some_param
          # The returned data should not contain *some_param* attribute
          expect(app.to_hash).to eq application
        end
      end

      context 'with an application that does not exist' do
        let(:non_existing_id) { '101' }

        it 'creating the application' do
          put "/services/#{service_id}/applications/#{non_existing_id}", { application: }.to_json

          expect(status).to eq 200
          expect(response_json['status']).to eq 'created'

          app = ThreeScale::Backend::Application.load(service_id, non_existing_id)
          expect(app.to_hash).to eq application.merge(id: non_existing_id)
        end
      end

      context 'without specifying the application' do
        let(:application) { nil }

        it 'trying to update the application' do
          put "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 400
          expect(response_json['status']).to eq 'error'
          expect(response_json['error']).to match /missing parameter/i
        end
      end

      context 'with an application that has no state' do
        let (:state) { nil }

        it 'Trying to create/update the application' do
          put "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 400
          expect(response_json['status']).to eq 'bad_request'
          expect(response_json['error']).to match /has no state/i
        end
      end

      context 'with a disabled service' do
        let (:service_id) { '6666' }

        it 'Trying to create/update the application' do
          ThreeScale::Backend::Service.save! id: service_id, provider_key: 'bar', state: :suspended

          put "/services/#{service_id}/applications/#{id}", { application: }.to_json

          expect(status).to eq 200
          expect(response_json['status']).to eq 'created'
        end
      end
    end

    context 'DELETE' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      it 'Deleting an application' do
        delete "/services/#{service_id}/applications/#{id}"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'deleted'
      end
    end
  end

  context '/services/:service_id/applications/key/:user_key' do

    # XXX Old API. DEPRECATED.
    context 'GET' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:user_key) { 'some_key' }
      let(:nonexistent_key) { 'nonexistent' }

      it 'Get existing ID of Application with service and key' do
        ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)

        get "/services/#{service_id}/applications/key/#{user_key}"

        expect(status).to eq 200
        expect(response_json['application']['id']).to eq id
      end

      it 'Try to get an Application ID from a non-existing key' do
        ThreeScale::Backend::Application.delete_id_by_key(service_id, nonexistent_key)

        get "/services/#{service_id}/applications/key/#{nonexistent_key}"

        expect(status).to eq 404
        expect(response_json['error']).to match /not found/i
      end
    end

    context 'DELETE' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:user_key) { 'some_key' }

      it 'Delete an Application\'s user key' do
        ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)

        delete "/services/#{service_id}/applications/key/#{user_key}"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'deleted'
        expect(ThreeScale::Backend::Application.
          load_id_by_key(service_id, user_key)).to be nil
      end
    end
  end

  describe 'PUT /services/:service_id/applications/:id/key/:user_key' do
    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:user_key) { 'some_key' }
    let(:another_key) { 'another_key' }

    it 'Change the key for an Application' do
      ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)

      put "/services/#{service_id}/applications/#{id}/key/#{another_key}"

      expect(status).to eq 200
      expect(response_json['status']).to eq 'modified'
      expect(ThreeScale::Backend::Application.
        load_id_by_key(service_id, another_key)).to eq id
    end
  end
end
