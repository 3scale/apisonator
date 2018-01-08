require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthUnexpectedParamsTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!

    setup_oauth_provider_fixtures

    @application = Application.save(service_id: @service.id,
                                    id: next_id,
                                    state: :active,
                                    plan_id: @plan_id,
                                    plan_name: @plan_name)
  end

  test 'ignores unexpected params' do
    get '/transactions/oauth_authorize.xml', provider_key: @provider_key,
                                             app_id: @application.id,
                                             some_param: 'some value'
    assert_authorized
  end
end
