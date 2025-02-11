describe 'UsageLimits (prefix: /services/:service_id/plans/:plan_id/usagelimits)' do

  let(:service_id) { '7575' }
  let(:plan_id) { '100' }

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'

    ThreeScale::Backend::Metric.delete(service_id, '100')
    ThreeScale::Backend::Metric.delete(service_id, '101')
    metric = ThreeScale::Backend::Metric.save(service_id: service_id, id: '100',
                                                 name: 'hits')
    metric_alt = ThreeScale::Backend::Metric.save(service_id: service_id, id: '101',
                                                   name: 'ads')
    @metric_h = { metric => { year: 1000, month: 200 },
                  metric_alt => { month: 100, day: 10 } }
    @metric_h.each do |m, h|
      ThreeScale::Backend::UsageLimit.save({service_id: m.service_id, plan_id: '100', metric_id: m.id}.merge!(h))
    end
  end

  context '/services/:service_id/plans/:plan_id/usagelimits/:metric_id/:period' do

    it 'Get UsageLimits' do
      @metric_h.each do |m, periods|
        periods.each do |period, value|
          get "/services/#{service_id}/plans/#{plan_id}/usagelimits/#{m.id}/#{period}"

          expect(response_json['usagelimit']['service_id']).to eq service_id
          expect(response_json['usagelimit']['plan_id']).to eq plan_id
          expect(response_json['usagelimit']['metric_id']).to eq m.id
          expect(response_json['usagelimit'][period.to_s]).to eq value
          expect(status).to eq 200
        end
      end
    end

    it 'Update UsageLimits' do
      @metric_h.each do |m, periods|
        periods.each do |p, value|
          put "/services/#{service_id}/plans/#{plan_id}/usagelimits/#{m.id}/#{p}", { usagelimit: { p.to_sym => value.succ.to_s } }.to_json

          expect(response_json['usagelimit']['service_id']).to eq service_id
          expect(response_json['usagelimit']['plan_id']).to eq plan_id
          expect(response_json['usagelimit']['metric_id']).to eq m.id
          expect(response_json['usagelimit'][p.to_s]).to eq value.succ.to_s
          expect(response_json['status']).to eq 'modified'
          expect(status).to eq 200

          expect(ThreeScale::Backend::UsageLimit.load_value(service_id, plan_id, m.id, p))
              .to eq value.succ
        end
      end
    end

    it 'Delete UsageLimits' do
      @metric_h.each do |m, periods|
        periods.each do |period, value|
          delete "/services/#{service_id}/plans/#{plan_id}/usagelimits/#{m.id}/#{period}"

          expect(response_json['status']).to eq 'deleted'
          expect(status).to eq 200

          expect(ThreeScale::Backend::UsageLimit.load_value(service_id, plan_id, m.id, period))
              .to be nil
        end
      end
    end
  end
end
