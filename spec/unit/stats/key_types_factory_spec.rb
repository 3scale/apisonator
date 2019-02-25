require_relative '../../spec_helper'

RSpec.shared_context 'type factory common context' do
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
  let(:job) { ThreeScale::Backend::Stats::DeleteJobDef.new job_params }
  subject { described_class.create(job).generator.to_a }
end

RSpec.describe ThreeScale::Backend::Stats::ResponseCodeServiceTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    let(:expected_keys) do
      %w[200 2XX 403 404 4XX 500 503 5XX].product(%i[hour day week month eternity]).map do |code, gr|
        ThreeScale::Backend::Stats::Keys.service_response_code_value_key(service_id, code, ThreeScale::Backend::Period[gr].new(from))
      end
    end

    it 'generates expected keys' do
      is_expected.to match_array expected_keys
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::ResponseCodeApplicationTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    context 'empty application array' do
      it 'does not generate keys' do
        is_expected.to match_array []
      end
    end

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

      it 'generates expected keys' do
        is_expected.to match_array expected_keys
      end
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::ResponseCodeUserTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    context 'empty user array' do
      it 'does not generate keys' do
        is_expected.to match_array []
      end
    end

    context 'some users in the array' do
      let(:users) { %w[1] }
      let(:expected_keys) do
        codes = %w[200 2XX 403 404 4XX 500 503 5XX]
        periods = %i[hour day week month year eternity]
        code_user_period = codes.product(users, periods)
        code_user_period.map do |code, user_id, gr|
          ThreeScale::Backend::Stats::Keys.user_response_code_value_key(service_id, user_id, code, ThreeScale::Backend::Period[gr].new(from))
        end
      end

      it 'generates expected keys' do
        is_expected.to match_array expected_keys
      end
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::UsageServiceTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    context 'empty metrics array' do
      it 'does not generate keys' do
        is_expected.to match_array []
      end
    end

    context 'some metrics in the array' do
      let(:metrics) { %w[1] }
      let(:expected_keys) do
        periods = %i[hour day week month eternity]
        metric_period = metrics.product(periods)
        metric_period.map do |metric_id, gr|
          ThreeScale::Backend::Stats::Keys.service_usage_value_key(service_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end
      it 'generates expected keys' do
        is_expected.to match_array expected_keys
      end
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::UsageApplicationTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    context 'empty applications array' do
      it 'does not generate keys' do
        is_expected.to match_array []
      end
    end

    context 'some applications in the array' do
      let(:metrics) { %w[1] }
      let(:applications) { %w[10] }
      let(:expected_keys) do
        periods = %i[hour day week month year eternity]
        metric_app_period = metrics.product(applications, periods)
        metric_app_period.map do |metric_id, app_id, gr|
          ThreeScale::Backend::Stats::Keys.application_usage_value_key(service_id, app_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end
      it 'generates expected keys' do
        is_expected.to match_array expected_keys
      end
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::UsageUserTypeFactory do
  include_context 'type factory common context'

  context '#create' do
    context 'empty user array' do
      it 'does not generate keys' do
        is_expected.to match_array []
      end
    end

    context 'some user in the array' do
      let(:metrics) { %w[1] }
      let(:users) { %w[20] }
      let(:expected_keys) do
        periods = %i[hour day week month year eternity]
        metric_user_period = metrics.product(users, periods)
        metric_user_period.map do |metric_id, user_id, gr|
          ThreeScale::Backend::Stats::Keys.user_usage_value_key(service_id, user_id, metric_id, ThreeScale::Backend::Period[gr].new(from))
        end
      end
      it 'generates expected keys' do
        is_expected.to match_array expected_keys
      end
    end
  end
end

RSpec.describe ThreeScale::Backend::Stats::KeyTypesFactory do
  include_context 'type factory common context'

  subject { described_class.create(job) }
  let(:expected_formatters) do
    [
      ThreeScale::Backend::Stats::KeyPartFormatter::ResponseCodeServiceTypeFormatter,
      ThreeScale::Backend::Stats::KeyPartFormatter::ResponseCodeApplicationTypeFormatter,
      ThreeScale::Backend::Stats::KeyPartFormatter::ResponseCodeUserTypeFormatter,
      ThreeScale::Backend::Stats::KeyPartFormatter::UsageServiceTypeFormatter,
      ThreeScale::Backend::Stats::KeyPartFormatter::UsageApplicationTypeFormatter,
      ThreeScale::Backend::Stats::KeyPartFormatter::UsageUserTypeFormatter
    ]
  end

  it 'all formatters included' do
    formatters = subject.map { |key_type| key_type.key_formatter.class }
    expect(formatters).to match_array expected_formatters
  end
end
