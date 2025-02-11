describe 'Stats (prefix: /services/:service_id/stats)' do
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
    }.to_json
  end

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'
    ThreeScale::Backend::Service.save!(provider_key: provider_key, id: existing_service_id)
  end

  context 'DELETE /services/:service_id/stats' do

    context 'PartitionGeneratorJob is enqueued' do
      before do
        ResqueSpec.reset!
      end

      it 'Deleting stats' do
        delete "/services/#{service_id}/stats"

        expect(status).to eq 200
        expect(response_json['status']).to eq 'to_be_deleted'
      end
    end

    context 'service does not exist' do
      let(:service_id) { existing_service_id + 'foo' }

      it 'Deleting stats' do
        delete "/services/#{service_id}/stats"

        expect(status).to eq 404
      end
    end
  end
end
