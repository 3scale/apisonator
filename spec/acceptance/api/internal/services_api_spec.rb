describe 'Services (prefix: /services)' do

  let(:someid) { '1001' }
  let(:otherid) { '2001' }
  let(:invalid_id) { '2002' }
  let(:provider_key) { 'foo' }
  let(:state) { :active }

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'

    ThreeScale::Backend::Service.save!(provider_key: provider_key, id: someid)
    ThreeScale::Backend::Service.save!(provider_key: provider_key, id: otherid, state: state)
  end

  context '/services/:id' do
    context 'GET' do
      let(:id) { someid }

      it 'Get Service by ID' do
        get "/services/#{id}"

        expect(response_json['service']['id']).to eq id
        expect(response_json['service']['provider_key']).to eq provider_key
        expect(status).to eq 200
      end

      it 'Try to get a Service by non-existent ID' do
        get "/services/#{invalid_id}"

        expect(status).to eq 404
        expect(response_json['error']).to match /not_found/
      end

      describe 'Get service and check state' do
        context 'when state is not set' do
          let(:id) { someid }
          it 'Get Service by ID' do
            get "/services/#{id}"

            expect(status).to eq 200
            expect(response_json['service']['id']).to eq id
            expect(response_json['service']['state']).to eq 'active'
          end
        end
        context 'when state is active' do
          let(:id) { otherid }
          it 'Get Service by ID' do
            get "/services/#{id}"

            expect(status).to eq 200
            expect(response_json['service']['id']).to eq id
            expect(response_json['service']['state']).to eq 'active'
          end
        end
        context 'when state is set to nil' do
          let(:id) { otherid }
          let(:state) { nil }
          it 'Get Service by ID' do
            get "/services/#{id}"

            expect(status).to eq 200
            expect(response_json['service']['id']).to eq id
            expect(response_json['service']['state']).to eq 'active'
          end
        end
        context 'when state is suspended' do
          let(:state) { :suspended }
          let(:id) { otherid }
          it 'Get Service by ID' do
            get "/services/#{id}"

            expect(status).to eq 200
            expect(response_json['service']['id']).to eq id
            expect(response_json['service']['state']).to eq state.to_s
          end
        end
        context 'when state is set to an invalid state' do
          let(:state) { :not_valid_state }
          let(:id) { otherid }
          it 'Get Service by ID' do
            get "/services/#{id}"

            expect(status).to eq 200
            expect(response_json['service']['id']).to eq id
            expect(response_json['service']['state']).to eq 'suspended'
          end
        end
      end
    end

    context 'PUT' do
      let(:id){ 1001 }
      let(:state) { :active }
      let(:service) do
        {
          provider_key: 'foo',
          referrer_filters_required: true,
          backend_version: 'oauth',
          default_service: true,
          state: state
        }
      end

      it 'Update Service by ID' do
        put "/services/#{id}", { service: }.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'ok'

        svc = ThreeScale::Backend::Service.load_by_id('1001')
        expect(svc.to_hash).to eq service.merge(id: '1001')
      end

      it 'Update Service by ID using extra params that should be ignored' do
        put "/services/#{id}", {service: service.merge(some_param: 'some_value')}.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'ok'

        svc = ThreeScale::Backend::Service.load_by_id('1001')
        expect(svc).not_to be_nil
        expect(svc).not_to respond_to :some_param
        # The returned data should not contain *some_param* attribute
        expect(svc.to_hash).to eq service.merge(id: '1001')
      end

      context 'Create a service that has no state' do
        let(:state) { nil }

        it 'creating the service returns an active service' do
          put "/services/#{id}", { service: }.to_json

          expect(status).to eq 200
          expect(response_json['status']).to eq 'ok'

          svc = ThreeScale::Backend::Service.load_by_id('1001')
          expect(svc.active?).to be_truthy
        end
      end

      context 'Create a Service with invalid state' do
        let(:state) { :invalid_state }

        it 'returns inactive service' do
          put "/services/#{id}", { service: }.to_json

          expect(status).to eq 200
          svc = ThreeScale::Backend::Service.load_by_id('1001')
          expect(svc).not_to be_nil
          expect(svc.active?).to be_falsy
        end
      end
    end

    context 'DELETE' do
      let(:default_service_id) { '1' }
      let(:non_default_service_id) { '2' }

      before { ThreeScale::Backend::Storage.instance.flushdb }

      it 'Deleting a default service when there are more' do
        [default_service_id, non_default_service_id].each do |id|
          ThreeScale::Backend::Service.save!(provider_key: provider_key, id: id)
        end

        delete "/services/#{default_service_id}"

        expect(status).to eq 400
        expect(response_json['error']).to match /cannot be removed/
      end

      it 'Deleting a default service when it is the only one' do
        ThreeScale::Backend::Service.save!(provider_key: provider_key, id: default_service_id)

        delete "/services/#{default_service_id}"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'deleted'
      end

      it 'Deleting a non-default service' do
        [default_service_id, non_default_service_id].each do |id|
          ThreeScale::Backend::Service.save!(provider_key: provider_key, id: id)
        end

        delete "/services/#{non_default_service_id}"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'deleted'
      end
    end
  end

  context 'POST /services/' do
    let(:state) { :active }
    let(:service) do
      {
        id: '1002',
        provider_key: 'foo',
        referrer_filters_required: true,
        backend_version: 'oauth',
        default_service: true,
        state: state
      }
    end

    it 'Create a Service' do
      post '/services/', { service: }.to_json

      expect(status).to eq 201
      expect(response_json['status']).to eq 'created'

      svc = ThreeScale::Backend::Service.load_by_id('1002')
      expect(svc.to_hash).to eq service
    end

    it 'Try creating a Service without specifying the service parameter in the body' do
      post '/services/'

      expect(status).to eq 400
      expect(response_json['error']).to match /missing parameter 'service'/
    end

    it 'Create a Service with extra params that should be ignored' do
      post '/services/', { service: service.merge(some_param: 'some_value') }.to_json

      expect(status).to eq 201
      expect(response_json['status']).to eq 'created'

      svc = ThreeScale::Backend::Service.load_by_id('1002')
      expect(svc).not_to be_nil
      expect(svc).not_to respond_to :some_param
      # The returned data should not contain *some_param* attribute
      expect(svc.to_hash).to eq service
    end

    context 'with an service that has no state' do
      let(:state) { nil }

      it 'creating the service returns an active service' do
        post '/services/', { service: }.to_json

        expect(status).to eq 201
        expect(response_json['status']).to eq 'created'

        svc = ThreeScale::Backend::Service.load_by_id('1002')
        expect(svc).not_to be_nil
        expect(svc.active?).to be_truthy
      end
    end

    context 'Create a Service with invalid state' do
      let(:state) { :invalid_state }

      it 'returns inactive service' do
        post '/services/', { service: }.to_json

        expect(status).to eq 201
        svc = ThreeScale::Backend::Service.load_by_id('1002')
        expect(svc).not_to be_nil
        expect(svc.active?).to be_falsy
      end
    end
  end

  context 'PUT /services/change_provider_key/:key' do
    let(:key){ 'foo' }
    let(:new_key){ 'bar' }

    it 'Changing a provider key' do
      put "/services/change_provider_key/#{key}", { new_key: }.to_json

      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
    end

    it 'Trying to change a provider key to empty' do
      put "/services/change_provider_key/#{key}"

      expect(status).to eq 400
      expect(response_json['error']).to match /keys are not valid/
    end

    it 'Trying to change a provider key to an existing one' do
      ThreeScale::Backend::Service.save! id: 7002, provider_key: 'bar'

      put "/services/change_provider_key/#{key}", { new_key: }.to_json

      expect(status).to eq 400
      expect(response_json['error']).to match /already exists/
    end

    it 'Trying to change a non-existent provider key' do
      put "/services/change_provider_key/baz", { new_key: }.to_json

      expect(status).to eq 400
      expect(response_json['error']).to match /does not exist/
    end
  end
end
