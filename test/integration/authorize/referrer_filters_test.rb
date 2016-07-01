require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizeReferrerFiltersTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!

    setup_provider_fixtures

    @service.referrer_filters_required = true # if this is disabled we bypass the verification
    @service.save!
    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
  end

  test 'succeeds if no referrer filter is defined and no referrer is passed' do
    @service.referrer_filters_required = false
    @service.save!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized
  end

  test 'succeeds if simple domain filter is defined and matching referrer is passed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'example.org'

    assert_authorized
  end

  test 'succeeds if wildcard domain filter is defined and matching referrer is passed' do
    @application.create_referrer_filter('*.bar.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'foo.bar.example.org'

    assert_authorized
  end

  test 'succeeds if a referrer filter is defined but referrer is bypassed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => '*'

    assert_authorized
  end

  test 'does not authorize if domain filter is defined but no referrer is passed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized 'referrer is missing'
  end

  test 'does not authorize if simple domain filter is defined but referrer does not match' do
    @application.create_referrer_filter('foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'bar.example.org'

    assert_not_authorized 'referrer "bar.example.org" is not allowed'
  end

  test 'does not authorize if wildcard domain filter is defined but referrer does not match' do
    @application.create_referrer_filter('*.foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'baz.bar.example.org'

    assert_not_authorized 'referrer "baz.bar.example.org" is not allowed'
  end

  test 'succeeds if referrer filters are not required' do
    @service.referrer_filters_required = false
    @service.save!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized
  end

  test 'succeeds if referrer filters are required and defined' do
    @application.create_referrer_filter('foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'foo.example.org'

    assert_authorized
  end

 test 'authorize always if referrer filters at the service level are set to false' do
    @service.referrer_filters_required = false
    @service.save!

    @application.create_referrer_filter('*.foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :referrer     => 'test.foo.example.org'

    assert_authorized
  end

  test 'authorize always if referrer filters at the service level are set to false, even when incorrect' do
    @service.referrer_filters_required = false
    @service.save!

    @application.create_referrer_filter('*.foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :referrer     => 'baz.bar.example.org'

    assert_authorized
  end
end
