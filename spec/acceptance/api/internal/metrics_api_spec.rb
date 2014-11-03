require_relative '../../acceptance_spec_helper'

resource 'Metrics (prefix: /services/:service_id/metrics)' do
  set_app ThreeScale::Backend::API::Internal
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
      response_json['metric']['id'].should == id
      response_json['metric']['service_id'].should == service_id
      status.should == 200
    end

    example 'Try to get a Metric by non-existent ID' do
      do_request id: id_non_existent
      status.should == 404
      response_json['error'].should =~ /metric not found/i
    end

    example 'Try to get a Metric by non-existent service ID' do
      do_request service_id: service_id_non_existent
      status.should == 404
      response_json['error'].should =~ /metric not found/i
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
      status.should == 201
      response_json['status'].should == 'created'

      (metric = ThreeScale::Backend::Metric.load(service_id, id)).should_not be_nil
      metric.id.should == id
      metric.service_id.should == service_id
      metric.name.should == name
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
      status.should == 200
      response_json['status'].should == 'modified'

      (metric = ThreeScale::Backend::Metric.load(service_id, id)).should_not be_nil
      metric.id.should == id
      metric.service_id.should == service_id
      metric.name.should == name
    end

  end

  delete '/services/:service_id/metrics/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Metric ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    example_request 'Deleting a Metric' do
      status.should == 200
      response_json['status'].should == 'deleted'
    end

  end

  # XXX This API should go away once UsageLimit is ported to Internal API
  get '/services/:service_id/metrics/all' do
    parameter :service_id, 'Service ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:another_id) { '101' }

    example 'Get all Metric IDs for a Service' do
      ThreeScale::Backend::Metric.save(service_id: service_id, id: another_id,
                                       name: 'another_name')
      do_request
      status.should == 200
      response_json['metric']['ids'].should == [id, another_id]
    end
  end

end
