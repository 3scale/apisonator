require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthRedirectUrlTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

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
                                    :redirect_url => 'http://3scale.net')

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_authorized
  end

  # these have to be checked against both 'redirect_url' and 'redirect_uri', as
  # they are both accepted, the former because of compatibility, and the latter
  # because of compliance with the OAuth spec.
  [:redirect_url, :redirect_uri].each do |redirect_fld|
    test "succeeds if its defined and the passed #{redirect_fld} matches" do
      @application = Application.save(:service_id   => @service.id,
                                      :id           => next_id,
                                      :state        => :active,
                                      :plan_id      => @plan_id,
                                      :plan_name    => @plan_name,
                                      :redirect_url => 'http://3scale.net')

      get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                               :app_id       => @application.id,
                                               redirect_fld  => 'http://3scale.net'

      assert_authorized
    end

    test "does not authorize if #{redirect_fld} is passed and doesnt match defined" do

      @application = Application.save(:service_id   => @service.id,
                                      :id           => next_id,
                                      :state        => :active,
                                      :plan_id      => @plan_id,
                                      :plan_name    => @plan_name,
                                      :redirect_url => 'http://3scale.net')

      get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                               :app_id       => @application.id,
                                               redirect_fld  => 'http://3scale.net2'

      assert_not_authorized "#{redirect_fld} \"http://3scale.net2\" is invalid"
    end

    test "returns #{redirect_fld} field if the request used it" do
      @application = Application.save(:service_id   => @service.id,
                                      :id           => next_id,
                                      :state        => :active,
                                      :plan_id      => @plan_id,
                                      :plan_name    => @plan_name,
                                      :redirect_url => 'http://3scale.net')

      get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                               :app_id       => @application.id,
                                               redirect_fld  => 'http://3scale.net'

      doc = Nokogiri::XML(last_response.body)

      redirect_url = doc.at("application/#{redirect_fld}")
      assert_not_nil redirect_url
      assert_equal @application.redirect_url, redirect_url.content
    end
  end

  test 'redirect_url takes precedence for compatibility over redirect_uri' do
    @application = Application.save(:service_id   => @service.id,
                                    :id           => next_id,
                                    :state        => :active,
                                    :plan_id      => @plan_id,
                                    :plan_name    => @plan_name,
                                    :redirect_url => 'http://3scale.net')

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :redirect_url => 'http://3scale.net',
                                             :redirect_uri => 'http://3scale.net2'
    assert_authorized

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :redirect_url => 'http://3scale.net2',
                                             :redirect_uri => 'http://3scale.net'
    assert_not_authorized "redirect_url \"http://3scale.net2\" is invalid"
  end
end
