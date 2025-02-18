describe 'Metrics (prefix: /services/:service_id/metrics)' do
  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'

    ThreeScale::Backend::Metric.delete('7575', '100')
    @metric = ThreeScale::Backend::Metric.save(service_id: '7575', id: '100',
                                                 name: 'hits')
  end

  context '/services/:service_id/metrics/:id' do
    context 'GET' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:service_id_non_existent) { service_id.to_i.succ.to_s }
      let(:id_non_existent) { id.to_i.succ.to_s }

      it 'Get Metric by ID' do
        get "/services/#{service_id}/metrics/#{id}"

        expect(response_json['metric']['id']).to eq id
        expect(response_json['metric']['service_id']).to eq service_id
        expect(status).to eq 200
      end

      it 'Try to get a Metric by non-existent ID' do
        get "/services/#{service_id}/metrics/#{id_non_existent}"

        expect(status).to eq 404
        expect(response_json['error']).to match /metric not found/i
      end

      it 'Try to get a Metric by non-existent service ID' do
        get "/services/#{service_id_non_existent}/metrics/#{id}"

        expect(status).to eq 404
        expect(response_json['error']).to match /metric not found/i
      end
    end

    context 'POST' do
      let(:service_id) { '7575' }
      let(:id) { '200' }
      let(:name) { 'rqps' }
      let(:metric) do
        {
          service_id: service_id,
          id: id,
          name: name,
        }
      end

      it 'Create a Metric' do
        post "/services/#{service_id}/metrics/#{id}", { metric: }.to_json

        expect(status).to eq 201
        expect(response_json['status']).to eq 'created'

        metric = ThreeScale::Backend::Metric.load(service_id, id)
        expect(metric.id).to eq id
        expect(metric.service_id).to eq service_id
        expect(metric.name).to eq name
      end

      it 'Create a Metric with extra params' do
        post "/services/#{service_id}/metrics/#{id}", { metric: metric.merge(some_param: 'some_val') }.to_json

        expect(status).to eq 201
        expect(response_json['status']).to eq 'created'

        metric = ThreeScale::Backend::Metric.load(service_id, id)
        expect(metric).not_to be_nil
        expect(metric).not_to respond_to :some_param
        expect(metric.id).to eq id
        expect(metric.service_id).to eq service_id
        expect(metric.name).to eq name
      end
    end

    context 'PUT' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      let(:name) { 'response_time' }
      let(:metric) do
        {
          service_id: service_id,
          id: id,
          name: name,
        }
      end

      it 'Update Metric by ID' do
        put "/services/#{service_id}/metrics/#{id}", { metric: }.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'modified'

        metric = ThreeScale::Backend::Metric.load(service_id, id)
        expect(metric.id).to eq id
        expect(metric.service_id).to eq service_id
        expect(metric.name).to eq name
      end

      it 'Update Metric by ID using extra params' do
        put "/services/#{service_id}/metrics/#{id}", { metric: metric.merge(some_param: 'some_val') }.to_json

        expect(status).to eq 200
        expect(response_json['status']).to eq 'modified'

        metric = ThreeScale::Backend::Metric.load(service_id, id)
        expect(metric).not_to be_nil
        expect(metric).not_to respond_to :some_param
        expect(metric.id).to eq id
        expect(metric.service_id).to eq service_id
        expect(metric.name).to eq name
      end
    end

    context 'DELETE' do
      let(:service_id) { '7575' }
      let(:id) { '100' }
      it 'Deleting a Metric' do
        delete "/services/#{service_id}/metrics/#{id}"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'deleted'
      end
    end
  end
end
