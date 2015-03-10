require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizeLegacyTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!

    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
  end

  test 'succeeds when valid legacy user key passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key     => user_key

    assert_authorized
  end

  test 'fails on invalid legacy user key passed' do
    Application.save_id_by_key(@service_id, 'foobar', @application.id)

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key     => 'biteme'

    assert_error_response :code    => 'user_key_invalid',
                          :message => 'user key "biteme" is invalid'
  end

  test 'fails when both application_id and legacy user key are passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :user_key     => user_key

    assert_error_response :code    => 'authentication_error',
                          :message => 'either app_id or user_key is allowed, not both'
  end
end
