require_relative '../../spec_helper'

def periods(granularity, from, to)
  (ThreeScale::Backend::Period[granularity].new(Time.at(from))..ThreeScale::Backend::Period[granularity].new(Time.at(to))).to_a
end

RSpec.describe ThreeScale::Backend::Stats::KeyGenerator do
  let(:service_id) { '123456' }
  let(:applications) { %w[] }
  let(:metrics) { %w[] }
  let(:users) { %w[] }
  let(:from) { Time.new(2002, 10, 31) }
  let(:to) { Time.new(2002, 11, 30) }
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
  let(:expected_keys_responsecode_service) do
    %w[200 2XX 403 404 4XX 500 503 5XX].product(%i[hour day week month eternity]).flat_map do |code, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.service_response_code_value_key(service_id, code, period)
      end
    end
  end
  let(:expected_keys_responsecode_application) do
    codes = %w[200 2XX 403 404 4XX 500 503 5XX]
    periods = %i[hour day week month year eternity]
    code_app_period = codes.product(applications, periods)
    code_app_period.flat_map do |code, app_id, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.application_response_code_value_key(service_id, app_id, code, period)
      end
    end
  end
  let(:expected_keys_responsecode_user) do
    codes = %w[200 2XX 403 404 4XX 500 503 5XX]
    periods = %i[hour day week month year eternity]
    code_app_period = codes.product(applications, periods)
    code_app_period.flat_map do |code, app_id, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.application_response_code_value_key(service_id, app_id, code, period)
      end
    end
  end
  let(:expected_keys_usage_service) do
    periods = %i[hour day week month eternity]
    metric_period = metrics.product(periods)
    metric_period.flat_map do |metric_id, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.service_usage_value_key(service_id, metric_id, period)
      end
    end
  end
  let(:expected_keys_usage_application) do
    periods = %i[hour day week month year eternity]
    metric_app_period = metrics.product(applications, periods)
    metric_app_period.flat_map do |metric_id, app_id, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.application_usage_value_key(service_id, app_id, metric_id, period)
      end
    end
  end
  let(:expected_keys_usage_user) do
    periods = %i[hour day week month year eternity]
    metric_user_period = metrics.product(users, periods)
    metric_user_period.flat_map do |metric_id, user_id, gr|
      periods(gr, from, to).flat_map do |period|
        ThreeScale::Backend::Stats::Keys.user_usage_value_key(service_id, user_id, metric_id, period)
      end
    end
  end

  subject { described_class.new(job_params).keys.to_a }

  context 'responsecode_service keys' do
    it 'include expected keys' do
      is_expected.to include(*expected_keys_responsecode_service)
    end
  end

  context 'responsecode_application keys' do
    let(:applications) { %w[1] }

    it 'include expected keys' do
      is_expected.to include(*expected_keys_responsecode_application)
    end
  end

  context 'responsecode_user keys' do
    let(:users) { %w[1] }

    it 'include expected keys' do
      is_expected.to include(*expected_keys_responsecode_user)
    end
  end

  context 'usage service keys' do
    let(:metrics) { %w[1] }

    it 'include expected keys' do
      is_expected.to include(*expected_keys_usage_service)
    end
  end

  context 'usage application keys' do
    let(:metrics) { %w[1] }
    let(:applications) { %w[10] }

    it 'include expected keys' do
      is_expected.to include(*expected_keys_usage_application)
    end
  end

  context 'usage user keys' do
    let(:metrics) { %w[1] }
    let(:users) { %w[10] }

    it 'include expected keys' do
      is_expected.to include(*expected_keys_usage_user)
    end
  end
  context 'usage user keys' do
    let(:metrics) { %w[1] }
    let(:users) { %w[10] }
    let(:applications) { %w[100] }
    it 'unexpected keys not found' do
      expect(subject.count).to eq([
        expected_keys_responsecode_service.count,
        expected_keys_responsecode_application.count,
        expected_keys_responsecode_user.count,
        expected_keys_usage_service.count,
        expected_keys_usage_application.count,
        expected_keys_usage_user.count
      ].reduce(:+))
    end
  end
end
