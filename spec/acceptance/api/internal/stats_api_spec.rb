resource 'Stats (prefix: /services/:service_id/stats)' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:existing_service_id) { '10000' }
  let(:service_id) { existing_service_id }
  let(:provider_key) { 'statsfoo' }
  let(:applications) { %w[1 2 3] }
  let(:metrics) { %w[10 20 30] }
  let(:from) { Time.new(2002, 10, 31).to_i }
  let(:to) { Time.new(2003, 10, 31).to_i }
  let(:req_body) do
    {
      deletejobdef: {
        applications: applications,
        metrics: metrics,
        from: from,
        to: to
      }
    }
  end
  # From and To fields are sent as string, even though they are integers in req_body
  let(:raw_post) { req_body }

  before do
    ThreeScale::Backend::Service.save!(provider_key: provider_key, id: existing_service_id)
  end

  delete '/services/:service_id/stats' do
    parameter :service_id, 'Service ID', required: true

    context 'PartitionGeneratorJob is enqueued' do
      before do
        ResqueSpec.reset!
      end

      example_request 'Deleting stats' do
        expect(status).to eq 200
        expect(response_json['status']).to eq 'to_be_deleted'
      end
    end

    context 'service does not exist' do
      let(:service_id) { existing_service_id + 'foo' }

      example_request 'Deleting stats' do
        expect(status).to eq 404
      end
    end
  end
end
