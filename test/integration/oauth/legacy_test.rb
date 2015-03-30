require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthLegacyTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  ENDPOINTS = [:oauth_authorize, :oauth_authrep]

  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!

    setup_oauth_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
  end

  # this tests that user_key is not considered when calling OAuth endpoints
  test 'doesnt succeed when valid legacy user key passed' do
    # register 'foobar' as a valid user_key
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    ENDPOINTS.each do |endpoint|
      get "/transactions/#{endpoint}.xml", provider_key: @provider_key,
                                           user_key: user_key
      assert_error_response status: 404,
                            code: 'application_not_found',
                            message: 'application with id="" was not found'
    end
  end
end
