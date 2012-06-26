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

  test 'CR(U)D oauth_access_token' do
    # Create
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'VALID-TOKEN'
    assert_equal 200, last_response.status

    # Read
    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    node = xml.at('oauth_access_tokens/oauth_access_token')

    assert_equal 1, node.count
    assert_equal 'VALID-TOKEN', node.content
    assert_equal '-1', node.attribute('ttl').value

    # Delete
    delete "/services/#{@service.id}/oauth_access_tokens/VALID-TOKEN",
           :provider_key => @provider_key
    assert_equal 200, last_response.status

    # Read again
    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert xml.at('oauth_access_tokens').element_children.empty?, 'No tokens should be present'
  end

  test 'create and read oauth_access_token with TTL supplied' do
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'VALID-TOKEN',
                                                             :ttl => 1000
    assert_equal 200, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status

    node = xml.at('oauth_access_tokens/oauth_access_token')
    assert_equal 1, node.count
    assert_equal 'VALID-TOKEN', node.content
    assert node.attribute('ttl').value.to_i > 0, "TTL should be positive"
  end


  test 'create oauth_access_token with invalid TTL returns 422' do
    [ -666, '', 'adbc'].each do |ttl|
      post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                               :app_id => @application.id,
                                                               :token => 'VALID-TOKEN',
                                                               :ttl => ttl

      assert_equal 422, last_response.status, "TTL '#{ttl}' should be invalid"

      get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
          :provider_key => @provider_key

      assert_equal 200, last_response.status
      assert xml.at('oauth_access_tokens').element_children.empty?
    end
  end

  test 'create oauth_access_token with invalid token returns 422' do
    ['', nil, [], {}, 'foo bar' ].each do |token|
      post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                               :app_id => @application.id,
                                                               :token => token

      assert_equal 422, last_response.status, "oauth access token '#{token.inspect}' should be invalid"

      get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
          :provider_key => @provider_key

      assert_equal 200, last_response.status
      assert xml.at('oauth_access_tokens').element_children.empty?
    end
  end

  test 'create oauth access token and retrieve the app_id later on' do

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'valid-token-666'
    assert_equal 200, last_response.status

    get "/services/#{@service.id}/oauth_access_tokens/valid-token-666.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)
    assert_equal @application.id, doc.at('app_id').content

  end

  test 'failed retrieve app_id by token' do

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'valid-token-666'
    assert_equal 200, last_response.status

    get "/services/#{@service.id}/oauth_access_tokens/fake-token.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'access_token_invalid',
                          :message => 'access_token "fake-token" is invalid: expired or never defined'

  end

  test 'check that service_id and provider_key match on return app_id by token' do

    get "/services/fake-service-id/oauth_access_tokens/fake-token.xml", :provider_key => @provider_key

    assert_error_response :status  => 403,
                          :code    => 'provider_key_invalid',
                          :message => "provider key \"#{@provider_key}\" is invalid"

    get "/services/#{@service.id}/oauth_access_tokens/fake-token.xml", :provider_key => "fake-provider-key"

    assert_error_response :status  => 403,
                          :code    => 'provider_key_invalid',
                          :message => 'provider key "fake-provider-key" is invalid'



  # TODO: test correct but different service_id with correct but other provider_id
  test 'CR(-)D with invalid invalid service' do
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => 'INVALID-KEY',
                                                             :app_id => @application.id,
                                                             :token => 'TOKEN'
    assert_equal 403, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => 'INVALID-KEY'
    assert_equal 403, last_response.status

    delete "/services/#{@service.id}/oauth_access_tokens/VALID-TOKEN",
           :provider_key => 'INVALID-KEY'
    assert_equal 403, last_response.status
  end


  test 'check that service_id and provider_key match' do

    post "/services/fake-service-id/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                              :app_id => @application.id,
                                                              :token => 'VALID-TOKEN',
                                                              :ttl => 1000

    assert_error_response :status  => 403,
                          :code    => 'provider_key_invalid',
                          :message => "provider key \"#{@provider_key}\" is invalid"


    post "/services/#{@service_id}/oauth_access_tokens.xml", :provider_key => "fake-provider-key",
                                                              :app_id => @application.id,
                                                              :token => 'VALID-TOKEN',
                                                              :ttl => 1000

    assert_error_response :status  => 403,
                          :code    => 'provider_key_invalid',
                          :message => 'provider key "fake-provider-key" is invalid'



  end

  test 'resuing an access token that is already in use fails, unless it is for a different service' do

    application2 = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)


    service2 = Service.save!(:provider_key => @provider_key, :id => next_id)

    application_diff_service = Application.save(:service_id => service2.id,
                                              :id         => next_id,
                                              :state      => :active,
                                              :plan_id    => @plan_id,
                                              :plan_name  => @plan_name)


    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'valid-token-666'
    assert_equal 200, last_response.status



    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => application2.id,
                                                             :token => 'valid-token-666'

    assert_error_response :status  => 403,
                         :code    => 'access_token_already_exists',
                         :message => 'access_token "valid-token-666" already exists'


    post "/services/#{service2.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                            :app_id => application_diff_service.id,
                                                            :token => 'valid-token-666'

    assert_equal 200, last_response.status


  end




  # test create token and delete it
  # test create token and delete it twice, should raise error on the second one (TO BE REMOVED?)
  # test create token with ttl, wait for it to expire, and then delete it (should raise error)
  # test create token with ttl, check that it's on the list of token, wait for it to expire, check that the list is empty, finally delete it (should raise error)
  # test create 10000 tokens for the single service and get the list of all the tokens. Check that it does not take less than 1 second.

  # test create token with service_id, app_id_1, then create the same token, same service_id and different app_id.
  # It should raise an error that the token is already assigned elsewhere.

  # test the same as above with a ttl. Wait for the first app_id->token to expire and assign the same token, it should not raise an error because the token is already
  # taken.

  # TODO: multiservice

  private

  def xml
    Nokogiri::XML(last_response.body)
  end

end

