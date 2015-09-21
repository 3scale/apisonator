require_relative '../../acceptance_spec_helper'

resource 'Utilization (prefix: /services/:service_id/applications/:app_id/utilization)' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  before(:all) do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end

  # Service IDs
  let(:service_id) { '1111' }
  let(:non_existing_service_id) { service_id.to_i.succ.to_s }
  let(:provider_key) { 'foo' }

  # Application IDs
  let(:app_id) { '2222' }
  let(:unlimited_app_id) { app_id.to_i.succ.to_s }
  let(:zero_limits_app_id) { unlimited_app_id.to_i.succ.to_s }
  let(:non_existing_app_id) { zero_limits_app_id.to_i.succ.to_s }

  # Plans
  let(:test_plan) do
    { id: '3333', name: 'my_plan' }
  end
  let(:no_limits_plan) do
    { id: test_plan[:id].to_i.succ.to_s, name: 'no_limits' }
  end
  let(:zero_limits_plan) do
    { id: no_limits_plan[:id].to_i.succ.to_s, name: 'zero_limits' }
  end

  # Applications
  let(:test_application) do
    { service_id: service_id,
      id: app_id,
      state: :active,
      plan_id: test_plan[:id],
      plan_name: test_plan[:name] }
  end

  let(:unlimited_plan_application) do
    { service_id: service_id,
      id: unlimited_app_id,
      state: :active,
      plan_id: no_limits_plan[:id],
      plan_name: no_limits_plan[:name] }
  end

  let(:zero_limits_plan_application) do
    { service_id: service_id,
      id: zero_limits_app_id,
      state: :active,
      plan_id: zero_limits_plan[:id],
      plan_name: zero_limits_plan[:name] }
  end

  # Metrics
  let(:test_metrics) do
    [{ service_id: service_id, id: '4444', name: 'hits' },
     { service_id: service_id, id: '5555', name: 'foos' }]
  end

  # Limits
  let(:hits_monthly_limit) { 1000 }
  let(:hits_daily_limit) { 100 }
  let(:foos_daily_limit) { 300 }
  let(:test_usage_limits) do
    [{ service_id: service_id,
       plan_id: test_plan[:id],
       metric_id: test_metrics[0][:id],
       month: hits_monthly_limit },
     { service_id: service_id,
       plan_id: test_plan[:id],
       metric_id: test_metrics[0][:id],
       day: hits_daily_limit },
     { service_id: service_id,
       plan_id: test_plan[:id],
       metric_id: test_metrics[1][:id],
       day: foos_daily_limit }]
  end

  let(:usage_limits_with_zeros) do
    [{ service_id: service_id,
       plan_id: zero_limits_plan[:id],
       metric_id: test_metrics[0][:id],
       month: 0 }]
  end

  def check_report(actual_report, expected_report)
    expect(actual_report['period']).to eq(expected_report[:period])
    expect(actual_report['metric_name']).to eq(expected_report[:metric_name])
    expect(actual_report['max_value']).to eq(expected_report[:max_value])
    expect(actual_report['current_value']).to eq(expected_report[:current_value])
  end

  get '/services/:service_id/applications/:app_id/utilization/' do
    parameter :service_id, 'Service ID', required: true
    parameter :app_id, 'Application ID', required: true

    before do
      ThreeScale::Backend::Service.save!(provider_key: provider_key,
                                         id: service_id)
      ThreeScale::Backend::TransactionStorage.delete_all(service_id)
      ThreeScale::Backend::Application.save(test_application)
      ThreeScale::Backend::Application.save(unlimited_plan_application)
      ThreeScale::Backend::Application.save(zero_limits_plan_application)
      test_metrics.each { |metric| ThreeScale::Backend::Metric.save(metric) }
      test_usage_limits.each { |limit| ThreeScale::Backend::UsageLimit.save(limit) }
      usage_limits_with_zeros.each { |limit| ThreeScale::Backend::UsageLimit.save(limit) }
    end

    context 'with valid service and app IDs' do
      context 'max usage is day' do
        let(:hits_transaction_1) { 50 }
        let(:hits_transaction_2) { 30 }
        let(:foos_transaction_3) { 100 }
        let(:test_transactions) do
          { 0 => { app_id: app_id,
                   usage: { hits: hits_transaction_1 },
                   timestamp: Time.now.to_s },
            1 => { app_id: app_id,
                   usage: { hits: hits_transaction_2 },
                   timestamp: Time.now.to_s },
            2 => { app_id: app_id,
                   usage: { foos: foos_transaction_3 },
                   timestamp: Time.now.to_s } }
        end

        before do
          ThreeScale::Backend::Worker.new
          with_resque do
            ThreeScale::Backend::Transactor.report(
                provider_key, service_id, test_transactions)
            ThreeScale::Backend::Transactor.process_batch(0, all: true)
          end
        end

        example_request 'Get utilization' do
          utilization = response_json['utilization']

          # Check usage reports
          usage_reports = utilization['usage_report']
          expect(usage_reports.size).to eq(test_usage_limits.size)

          check_report(usage_reports[0],
                       { period: 'month',
                         metric_name: 'hits',
                         max_value: hits_monthly_limit,
                         current_value: hits_transaction_1 + hits_transaction_2 })

          check_report(usage_reports[1],
                       { period: 'day',
                         metric_name: 'hits',
                         max_value: hits_daily_limit,
                         current_value: hits_transaction_1 + hits_transaction_2 })

          check_report(usage_reports[2],
                       { period: 'day',
                         metric_name: 'foos',
                         max_value: foos_daily_limit,
                         current_value: foos_transaction_3})

          # Check max usage report
          check_report(utilization['max_usage_report'],
                       { period: 'day',
                         metric_name: 'hits',
                         max_value: hits_daily_limit,
                         current_value: hits_transaction_1 + hits_transaction_2 })

          # Check max utilization
          total_hits_registered = hits_transaction_1 + hits_transaction_2
          expect(utilization['max_utilization'])
              .to eq(total_hits_registered*100/hits_daily_limit)

          # Check stats
          expect(utilization['stats']).to be_empty

          expect(response_status).to eq(200)
        end
      end

      context 'max usage is month' do
        let(:hits_transaction_1) { 0 }
        let(:hits_transaction_2) { 100 }
        let(:test_transactions) do
          { 0 => { app_id: app_id,
                   usage: { hits: hits_transaction_1 },
                   timestamp: Time.now.to_s },
            1 => { app_id: app_id,
                   usage: { hits: hits_transaction_2 },
                   timestamp: Time.now - 60*60*24 } } #yesterday
        end

        before do
          ThreeScale::Backend::Worker.new
          with_resque do
            ThreeScale::Backend::Transactor.report(
                provider_key, service_id, test_transactions)
            ThreeScale::Backend::Transactor.process_batch(0, all: true)
          end
        end

        example_request 'Get utilization' do
          utilization = response_json['utilization']

          # Check usage reports
          usage_reports = utilization['usage_report']
          expect(usage_reports.size).to eq(test_usage_limits.size)

          # Check max usage report
          check_report(utilization['max_usage_report'],
                       { period: 'month',
                         metric_name: 'hits',
                         max_value: hits_monthly_limit,
                         current_value: hits_transaction_1 + hits_transaction_2 })

          # Check max utilization
          total_hits_registered = hits_transaction_1 + hits_transaction_2
          expect(utilization['max_utilization'])
              .to eq(total_hits_registered*100/hits_monthly_limit)

          # Check stats
          expect(utilization['stats']).to be_empty

          expect(response_status).to eq(200)
        end
      end

      context 'with application with unlimited plan' do
        example 'Get utilization' do
          do_request(app_id: unlimited_app_id)
          utilization = response_json['utilization']
          expect(utilization['usage_report']).to be_empty
          expect(utilization['max_usage_report']).to be_nil
          expect(utilization['max_utilization']).to be_nil
          expect(utilization['stats']).to be_empty
          expect(response_status).to eq(200)
        end
      end

      context 'with application with zero limits plan' do
        example 'Get utilization' do
          do_request(app_id: zero_limits_app_id)
          utilization = response_json['utilization']
          usage_reports = utilization['usage_report']

          expect(usage_reports.size).to eq(1)
          check_report(usage_reports[0],
                       { period: 'month',
                         metric_name: 'hits',
                         max_value: usage_limits_with_zeros[0][:month],
                         current_value: 0 })

          check_report(utilization['max_usage_report'],
                       { period: 'month',
                         metric_name: 'hits',
                         max_value: usage_limits_with_zeros[0][:month],
                         current_value: 0 })

          expect(utilization['max_utilization']).to be_zero
          expect(utilization['stats']).to be_empty

          expect(response_status).to eq(200)
        end
      end
    end

    context 'with non-existing service ID' do
      example 'Try to get utilization' do
        do_request(service_id: non_existing_service_id)
        expect(response_status).to eq(404)
      end
    end

    context 'with non-existing app ID' do
      example 'Try to get utilization' do
        do_request(app_id: non_existing_app_id)
        expect(response_status).to eq(404)
      end
    end
  end
end
