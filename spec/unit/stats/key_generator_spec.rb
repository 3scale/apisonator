require_relative '../../spec_helper'

RSpec.describe ThreeScale::Backend::Stats::KeyGenerator do
  let(:service_id) { '123456' }
  let(:applications) { %w[] }
  let(:metrics) { %w[] }
  let(:users) { %w[] }
  let(:from) { Time.new(2002, 10, 31) }
  let(:to) { Time.new(2002, 10, 31) }
  let(:job_params) do
    {
      service_id: service_id,
      applications: applications,
      metrics: metrics,
      users: users,
      from: from.to_i,
      to: to.to_i
    }
  end
  subject { described_class.new(job_params).keys }

  context 'responsecode_service keys' do
    let(:expected_keys) do
      %w[200 2XX 403 404 4XX 500 503 5XX].product(%i[hour day week month eternity]).map do |code, gr|
        ThreeScale::Backend::Stats::Keys.service_response_code_value_key(service_id, code, ThreeScale::Backend::Period[gr].new(from))
      end
    end

    it 'include expected keys' do
      is_expected.to include(*expected_keys)
    end
  end

  context 'responsecode_application keys' do
    context 'some applications in the array' do
      let(:applications) { %w[1] }
      let(:expected_keys) do
        codes = %w[200 2XX 403 404 4XX 500 503 5XX]
        periods = %i[hour day week month year eternity]
        code_app_period = codes.product(applications, periods)
        code_app_period.map do |code, app_id, gr|
          ThreeScale::Backend::Stats::Keys.application_response_code_value_key(service_id, app_id, code, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'include expected keys' do
        is_expected.to include(*expected_keys)
      end
    end
  end

  context 'responsecode_user keys' do
    context 'some users in the array' do
      let(:users) { %w[1] }
      let(:expected_keys) do
        codes = %w[200 2XX 403 404 4XX 500 503 5XX]
        periods = %i[hour day week month year eternity]
        code_app_period = codes.product(applications, periods)
        code_app_period.map do |code, app_id, gr|
          ThreeScale::Backend::Stats::Keys.application_response_code_value_key(service_id, app_id, code, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'include expected keys' do
        is_expected.to include(*expected_keys)
      end
    end
  end

  context 'usage service keys' do
    context 'some metrics in the array' do
      let(:metrics) { %w[1] }
      let(:expected_keys) do
        periods = %i[hour day week month eternity]
        metric_period = metrics.product(periods)
        metric_period.map do |metric_id, gr|
          ThreeScale::Backend::Stats::Keys.service_usage_value_key(service_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'include expected keys' do
        is_expected.to include(*expected_keys)
      end
    end
  end

  context 'usage application keys' do
    context 'some metrics applications in the array' do
      let(:metrics) { %w[1] }
      let(:applications) { %w[10] }
      let(:expected_keys) do
        periods = %i[hour day week month year eternity]
        metric_app_period = metrics.product(applications, periods)
        metric_app_period.map do |metric_id, app_id, gr|
          ThreeScale::Backend::Stats::Keys.application_usage_value_key(service_id, app_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'include expected keys' do
        is_expected.to include(*expected_keys)
      end
    end
  end

  context 'usage user keys' do
    context 'some metrics users in the array' do
      let(:metrics) { %w[1] }
      let(:users) { %w[10] }
      let(:expected_keys) do
        periods = %i[hour day week month year eternity]
        metric_user_period = metrics.product(users, periods)
        metric_user_period.map do |metric_id, user_id, gr|
          ThreeScale::Backend::Stats::Keys.user_usage_value_key(service_id, user_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'include expected keys' do
        is_expected.to include(*expected_keys)
      end
    end
  end
end
