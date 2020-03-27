require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthRepResponseCodesTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::AuthRep
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_oauth_provider_fixtures

    @application = Application.save(service_id: @service.id,
                                    id: next_id,
                                    state: :active,
                                    plan_id: @plan_id,
                                    plan_name: @plan_name)

    @metric_id = next_id
    Metric.save(service_id: @service.id, id: @metric_id, name: 'hits')
  end

  test_authrep 'can report response codes' do |e|
    current_time = Time.utc(2020, 1, 1)

    Timecop.freeze(current_time) do
      get e, {
        provider_key: @provider_key,
        app_id: @application.id,
        usage: { 'hits' => 1 },
        log: { code: 200 }
      }

      Resque.run!
    end

    assert_equal 200, last_response.status
    assert_equal '1', @storage.get(response_code_key(@service_id, '200', :day, '20200101'))
    assert_equal '1', @storage.get(response_code_key(@service_id, '2XX', :day, '20200101'))
  end

  test_authrep 'no longer supported log attrs (request, response) are ignored in report jobs' do |e|
    get e, {
      provider_key: @provider_key,
      app_id: @application.id,
      usage: { 'hits' => 1 },
      log: { code: 200,
             request: 'some_request',
             response: 'some_response' }
    }

    enqueued_job = Resque.list_range(:priority)

    # transactions is the second arg ([1]), we only sent one (['0'])
    transaction = enqueued_job['args'][1]['0']
    assert_nil transaction['log']['request']
    assert_nil transaction['log']['response']
  end
end
