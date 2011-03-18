require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthRedirectUrlTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb

    setup_oauth_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)
  end

  test 'succeeds if its not passed and not defined' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_authorized
  end

  test 'succeeds if its not passed and defined' do
    @application = Application.save(:service_id   => @service.id,
                                    :id           => next_id,
                                    :state        => :active,
                                    :plan_id      => @plan_id,
                                    :plan_name    => @plan_name,
                                    :redirect_url => "http://3scale.net")

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_authorized
  end

  test 'succeeds if its defined and the passed redirect_url matches' do
    @application = Application.save(:service_id   => @service.id,
                                    :id           => next_id,
                                    :state        => :active,
                                    :plan_id      => @plan_id,
                                    :plan_name    => @plan_name,
                                    :redirect_url => "http://3scale.net")

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :redirect_url => "http://3scale.net"

    assert_authorized
  end
  test 'does not authorize if its passed and doesnt match defined' do

    @application = Application.save(:service_id   => @service.id,
                                    :id           => next_id,
                                    :state        => :active,
                                    :plan_id      => @plan_id,
                                    :plan_name    => @plan_name,
                                    :redirect_url => "http://3scale.net")

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :redirect_url => "http://3scale.net2"

    assert_not_authorized 'redirect_url "http://3scale.net2" is invalid'
  end
end
