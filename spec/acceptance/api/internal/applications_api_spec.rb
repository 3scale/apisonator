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

  describe 'PUT /services/:service_id/applications/batch' do
    let(:service_id) { '7575' }

    context 'with valid applications' do
      it 'creates multiple applications successfully' do
        batch_data = {
          applications: [
            {
              id: 'app_1',
              state: 'active',
              plan_id: '123',
              plan_name: 'Gold',
              redirect_url: 'http://example.com',
              user_key: 'user_key_1',
              application_keys: ['key1', 'key2'],
              referrer_filters: ['example.com', '*.example.org']
            },
            {
              id: 'app_2',
              state: 'suspended',
              plan_id: '124',
              plan_name: 'Silver'
            },
            {
              id: 'app_3',
              state: 'active',
              plan_id: '125',
              plan_name: 'Bronze',
              user_key: 'user_key_3'
            }
          ]
        }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'completed'
        expect(response_json['total']).to eq 3
        expect(response_json['successful']).to eq 3
        expect(response_json['failed']).to eq 0
        expect(response_json['failures']).to be_nil
        expect(response_json['applications']).to be_an(Array)
        expect(response_json['applications'].size).to eq 3

        # Verify app_1 result
        app1_result = response_json['applications'][0]
        expect(app1_result['status']).to eq 'created'
        expect(app1_result['application']['id']).to eq 'app_1'
        expect(app1_result['application']['state']).to eq 'active'
        expect(app1_result['application']['plan_id']).to eq '123'
        expect(app1_result['application']['plan_name']).to eq 'Gold'
        expect(app1_result['application']['redirect_url']).to eq 'http://example.com'
        expect(app1_result['application']['user_key']).to eq 'user_key_1'
        expect(app1_result['application']['application_keys']).to contain_exactly('key1', 'key2')
        expect(app1_result['application']['referrer_filters']).to contain_exactly('example.com', '*.example.org')

        # Verify app_2 result
        app2_result = response_json['applications'][1]
        expect(app2_result['status']).to eq 'created'
        expect(app2_result['application']['id']).to eq 'app_2'
        expect(app2_result['application']['state']).to eq 'suspended'
        expect(app2_result['application']['user_key']).to be_nil

        # Verify app_3 result
        app3_result = response_json['applications'][2]
        expect(app3_result['status']).to eq 'created'
        expect(app3_result['application']['id']).to eq 'app_3'
        expect(app3_result['application']['user_key']).to eq 'user_key_3'

        # Verify data in storage
        expect(ThreeScale::Backend::Application.load_id_by_key(service_id, 'user_key_1')).to eq 'app_1'
        expect(ThreeScale::Backend::Application.load_id_by_key(service_id, 'user_key_3')).to eq 'app_3'
      end
    end

    context 'with some invalid applications' do
      it 'reports failures for invalid applications' do
        batch_data = {
          applications: [
            {
              id: 'app_1',
              state: 'active',
              plan_id: '123',
              plan_name: 'Gold'
            },
            {
              id: 'app_2',
              plan_id: '124',
              plan_name: 'Silver'
            },
            {
              id: 'app_3',
              state: 'active',
              plan_id: '125',
              plan_name: 'Bronze',
              referrer_filters: ['']
            }
          ]
        }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'completed'
        expect(response_json['total']).to eq 3
        expect(response_json['successful']).to eq 1
        expect(response_json['failed']).to eq 2
        expect(response_json['applications']).to be_an(Array)
        expect(response_json['applications'].size).to eq 3
        expect(response_json['failures']).to be_an(Array)
        expect(response_json['failures'].size).to eq 2

        # Verify app_1 succeeded
        app1_result = response_json['applications'][0]
        expect(app1_result['status']).to eq 'created'
        expect(app1_result['application']['id']).to eq 'app_1'
        expect(app1_result['application']['state']).to eq 'active'

        # Verify app_2 failed (no state)
        app2_result = response_json['applications'][1]
        expect(app2_result['status']).to eq 'error'
        expect(app2_result['id']).to eq 'app_2'
        expect(app2_result['error']).to match(/has no state/i)

        # Verify app_3 failed (invalid referrer filter)
        app3_result = response_json['applications'][2]
        expect(app3_result['status']).to eq 'error'
        expect(app3_result['id']).to eq 'app_3'
        expect(app3_result['error']).to match(/referrer filter/i)

        # Verify failures array
        failure_ids = response_json['failures'].map { |f| f['id'] }
        expect(failure_ids).to contain_exactly('app_2', 'app_3')

        # Verify data in storage
        app1 = ThreeScale::Backend::Application.load(service_id, 'app_1')
        expect(app1).not_to be_nil
        expect(app1.state).to eq :active

        app2 = ThreeScale::Backend::Application.load(service_id, 'app_2')
        expect(app2).to be_nil

        # app_3 is created despite referrer filter error (partial success)
        app3 = ThreeScale::Backend::Application.load(service_id, 'app_3')
        expect(app3).not_to be_nil
        expect(app3.state).to eq :active
        # But the invalid referrer filter is not added
        expect(app3.referrer_filters).to be_empty
      end
    end

    context 'with missing applications parameter' do
      it 'returns 400 error' do
        put "/services/#{service_id}/applications/batch", {}.to_json

        expect(status).to eq 400
        expect(response_json['status']).to eq 'error'
        expect(response_json['error']).to match /missing parameter/i
      end
    end

    context 'with empty applications array' do
      it 'returns success with zero applications processed' do
        batch_data = { applications: [] }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'completed'
        expect(response_json['total']).to eq 0
        expect(response_json['successful']).to eq 0
        expect(response_json['failed']).to eq 0
        expect(response_json['applications']).to eq []
      end
    end

    context 'with validation errors' do
      it 'fails when application has no ID' do
        batch_data = {
          applications: [
            {
              state: 'active',
              plan_id: '123',
              plan_name: 'Gold'
            }
          ]
        }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'completed'
        expect(response_json['total']).to eq 1
        expect(response_json['successful']).to eq 0
        expect(response_json['failed']).to eq 1

        app_result = response_json['applications'][0]
        expect(app_result['status']).to eq 'error'
        expect(app_result['error']).to match(/has no id/i)
      end

      it 'fails when application has no state' do
        batch_data = {
          applications: [
            {
              id: 'app_1',
              plan_id: '123',
              plan_name: 'Gold'
            }
          ]
        }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'completed'
        expect(response_json['total']).to eq 1
        expect(response_json['successful']).to eq 0
        expect(response_json['failed']).to eq 1

        app_result = response_json['applications'][0]
        expect(app_result['status']).to eq 'error'
        expect(app_result['id']).to eq 'app_1'
        expect(app_result['error']).to match(/has no state/i)
      end
    end

    context 'when updating existing applications' do
      it 'returns modified status for existing apps' do
        # Create an existing application
        ThreeScale::Backend::Application.save(
          service_id: service_id,
          id: 'existing_app',
          state: :active,
          plan_id: '100',
          plan_name: 'Old Plan'
        )

        batch_data = {
          applications: [
            {
              id: 'existing_app',
              state: 'active',
              plan_id: '200',
              plan_name: 'New Plan'
            },
            {
              id: 'new_app',
              state: 'active',
              plan_id: '300',
              plan_name: 'Brand New'
            }
          ]
        }

        put "/services/#{service_id}/applications/batch", batch_data.to_json

        expect(status).to eq 200
        expect(response_json['successful']).to eq 2

        # Verify existing app was modified
        existing_result = response_json['applications'][0]
        expect(existing_result['status']).to eq 'modified'
        expect(existing_result['application']['id']).to eq 'existing_app'
        expect(existing_result['application']['plan_id']).to eq '200'
        expect(existing_result['application']['plan_name']).to eq 'New Plan'

        # Verify new app was created
        new_result = response_json['applications'][1]
        expect(new_result['status']).to eq 'created'
        expect(new_result['application']['id']).to eq 'new_app'
      end
    end
  end
end
