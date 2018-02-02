require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepUnexpectedParamsTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::AuthRep

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

  test_authrep 'ignores unexpected params' do |e|
    get e, provider_key: @provider_key,
           app_id: @application.id,
           some_param: 'some value'

    assert_authorized
  end
end
