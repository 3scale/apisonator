require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class BackendVersionTest < Test::Unit::TestCase
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

    Application.save_id_by_key(@service_id, "user_key_#{@application.id}", @application.id)
  end

  test 'test app_id and user_key are not exchangeable and are bound to the backend_version' do
    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '1'

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_error_response :status  => 403,
                          :code    => 'user_key_invalid',
                          :message => 'user key is missing'

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key     => "user_key_#{@application.id}"

    assert_authorized

    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '2'

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key     => "user_key_#{@application.id}"

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application id is missing'
  end

  test 'service originally on backend_version 2 with apps with app_key does not complain about missing app_key when changed to backend_version 1' do
    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '2'

    application_key_one = @application.create_key
    application_key_two = @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one

    assert_authorized

    ## this needs to be done because the server is cached on the memoizer
    Memoizer.reset!

    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '1'

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key       => "user_key_#{@application.id}"

    assert_authorized

    ## this needs to be done because the server is cached on the memoizer
    Memoizer.reset!

    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '2'

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_two

    assert_authorized
  end

  test 'when backend_version is not declared should behave like backend_version two regarding the presence of app_key' do
    if @service.backend_version.nil? || @service.backend_version.empty?
      application_key_one = @application.create_key

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one

      assert_authorized

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key       => "user_key_#{@application.id}"

      assert_error_response :status  => 404,
                            :code    => 'application_not_found',
                            :message => 'application id is missing'
    end
  end

  test 'when backend_version is 2 and we switch to oauth, there is no complaint about missing app_keys when calling auth endpoints' do
    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '2'

    application_key_one = @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one
    assert_authorized

    Memoizer.reset!

    Service.save! id: @service.id, provider_key: @provider_key, backend_version: 'oauth'

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized
  end

  test 'when backend_version is 2 and we switch to oauth, app_keys are checked if passing in app_key' do
    Service.save! id: @service.id, provider_key: @provider_key, backend_version: '2'

    application_key_one = @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one
    assert_authorized

    Memoizer.reset!

    Service.save! id: @service.id, provider_key: @provider_key, backend_version: 'oauth'

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => 'invalid_key'

    assert_not_authorized

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one

    assert_authorized

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized
  end
end
