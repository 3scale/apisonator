resource 'Metrics (prefix: /services/:service_id/metrics)' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  before do
    ThreeScale::Backend::Metric.delete('7575', '100')
    @metric = ThreeScale::Backend::Metric.save(service_id: '7575', id: '100',
                                                 name: 'hits')
  end

  get '/services/:service_id/metrics/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Metric ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:service_id_non_existent) { service_id.to_i.succ.to_s }
    let(:id_non_existent) { id.to_i.succ.to_s }

    example_request 'Get Metric by ID' do
      expect(response_json['metric']['id']).to eq id
      expect(response_json['metric']['service_id']).to eq service_id
      expect(status).to eq 200
    end

    example 'Try to get a Metric by non-existent ID' do
      do_request id: id_non_existent
      expect(status).to eq 404
      expect(response_json['error']).to match /metric not found/i
    end

    example 'Try to get a Metric by non-existent service ID' do
      do_request service_id: service_id_non_existent
      expect(status).to eq 404
      expect(response_json['error']).to match /metric not found/i
    end
  end

  post '/services/:service_id/metrics/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Metric ID', required: true
    parameter :metric, 'Metric attributes', required: true

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
    let(:raw_post){ params.to_json }

    example_request 'Create a Metric' do
      expect(status).to eq 201
      expect(response_json['status']).to eq 'created'

      metric = ThreeScale::Backend::Metric.load(service_id, id)
      expect(metric.id).to eq id
      expect(metric.service_id).to eq service_id
      expect(metric.name).to eq name
    end

    example 'Create a Metric with extra params' do
      do_request metric: metric.merge(some_param: 'some_val')
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

  put '/services/:service_id/metrics/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Metric ID', required: true
    parameter :metric, 'Metric attributes', required: true

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
    let(:raw_post){ params.to_json }

    example_request 'Update Metric by ID' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'modified'

      metric = ThreeScale::Backend::Metric.load(service_id, id)
      expect(metric.id).to eq id
      expect(metric.service_id).to eq service_id
      expect(metric.name).to eq name
    end

    example 'Update Metric by ID using extra params' do
      do_request metric: metric.merge(some_param: 'some_val')
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

  delete '/services/:service_id/metrics/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Metric ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    example_request 'Deleting a Metric' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'deleted'
    end

  end

end
