require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizeUnexpectedParamsTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!

    setup_provider_fixtures

    @application = Application.save(service_id: @service.id,
                                    id: next_id,
                                    state: :active,
                                    plan_id: @plan_id,
                                    plan_name: @plan_name)
  end

  test 'ignores unexpected params' do
    application_key = @application.create_key

    get '/transactions/authorize.xml', provider_key: @provider_key,
                                       app_id: @application.id,
                                       app_key: application_key,
                                       some_param: 'some value'

    assert_authorized
  end
end
