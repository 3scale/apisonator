require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthLegacyTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb

    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
  end

  test 'doesnt succeed when valid legacy user key passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :user_key     => user_key
    assert_not_authorized
  end
end
