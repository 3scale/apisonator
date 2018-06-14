require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthRepDisabledServiceBasicTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::Extensions

  include TestHelpers::AuthRep

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

    @application = Application.save(service_id: @service.id,
                                    id: next_id,
                                    state: :active,
                                    plan_id: @plan_id,
                                    plan_name: @plan_name)

    Service.save!(id: @service_id, provider_key: @provider_key, state: :suspended)
  end

  test 'authrep on disabled service responds with 409' do
    get '/transactions/authrep.xml', provider_key: @provider_key,
                                     app_id: @application.id

    assert_not_authorized 'service is not active'
  end
end
