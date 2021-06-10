require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepApplicationKeysTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  include TestHelpers::AuthRep

  def setup
    Storage.instance(true).flushdb

    Memoizer.reset!

    setup_provider_fixtures
    setup_oauth_provider_fixtures_noclobber

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
    @application_oauth = Application.save(:service_id => @service_oauth.id,
                                          :id         => next_id,
                                          :state      => :active,
                                          :plan_id    => @plan_id,
                                          :plan_name  => @plan_name)
  end

  test_authrep 'succeeds if no application key is defined nor passed' do |e|
    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id

    assert_authorized
  end

  test_authrep 'succeeds if one application key is defined and the same one is passed' do |e|
    application_key = @application_oauth.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => application_key

    assert_authorized
  end

  test_authrep 'succeeds if multiple application keys are defined and one of them is passed' do |e|
    application_key_one = @application_oauth.create_key
    _application_key_two = @application_oauth.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => application_key_one

    assert_authorized
  end

  test_authrep 'does not authorize if application key is defined but not passed for non oauth services',
               except: :oauth_authrep do |e|
    @application.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service.id,
           :app_id       => @application.id

    assert_not_authorized 'application key is missing'
  end

  test_authrep 'authorizes if application key is defined but not passed if the service is oauth' do |e|
    @application_oauth.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id

    assert_authorized
  end

  test_authrep 'authorizes if application key is defined and matches if the service is oauth' do |e|
    application_key = @application_oauth.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => application_key

    assert_authorized
  end

  test_authrep 'does not authorize if application key is defined but wrong even if the service is oauth',
               except: :oauth_authrep do |e|
    @application_oauth.create_key 'some_key'

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => 'invalid_key'

    assert_not_authorized 'application key "invalid_key" is invalid'
  end

  test_authrep 'authorize with a random app key and a custom one' do |e|
    key1 = @application_oauth.create_key 'foo_app_key'
    key2 = @application_oauth.create_key

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => key1

    assert_authorized

    get e, :provider_key => @provider_key,
           :service_id   => @service_oauth.id,
           :app_id       => @application_oauth.id,
           :app_key      => key2

    assert_authorized

    assert_equal key1, 'foo_app_key'
    assert_equal [key2, 'foo_app_key'].sort, @application_oauth.keys.sort
  end
end
