require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepLegacyTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  include TestHelpers::AuthRep

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

  test_authrep 'succeeds when valid legacy user key passed' do |e, method|
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    get e, :provider_key => @provider_key,
           :user_key     => user_key

    if method == :oauth_authrep
      assert_error_response status: 404,
                            code: 'application_not_found'
    else
      assert_authorized
    end
  end

  test_authrep 'fails on invalid legacy user key passed' do |e, method|
    Application.save_id_by_key(@service_id, 'foobar', @application.id)

    get e, :provider_key => @provider_key,
           :user_key     => 'biteme'

    error_response = case method
                     when :oauth_authrep
                       { status: 404,
                         code: 'application_not_found' }
                     else
                       { code: 'user_key_invalid',
                         message: 'user key "biteme" is invalid' }
                     end

    assert_error_response error_response
  end

  test_authrep 'fails when both application_id and legacy user key are passed' do |e|
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    get e, :provider_key => @provider_key,
           :app_id       => @application.id,
           :user_key     => user_key

    assert_error_response :code    => 'authentication_error',
                          :message => 'either app_id or user_key is allowed, not both'
  end
end
