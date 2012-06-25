require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AccessTokenTest < Test::Unit::TestCase
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

  test 'create and read oauth_access_token' do
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'VALID-TOKEN'
    assert_equal 200, last_response.status

    get "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key
    puts last_response.body
    # doc   = Nokogiri::XML(last_response.body)
  end

  # TODO: TTL
  # TODO: multiservice

end

