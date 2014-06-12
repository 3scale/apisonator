require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AccessTokenTest < Test::Unit::TestCase
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
    delete "/services/#{@service.id}/oauth_access_tokens/VALID-TOKEN.xml",
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
    [ -666, 0, '', 'adbc'].each do |ttl|
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
    s = (0...256+1).map{65.+(rand(25)).chr}.join
    ['', nil, [], {}, s].each do |token|
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

  test 'create oauth_access_token with valid tokens' do
    s = (0...255).map{65.+(rand(25)).chr}.join
    ['foo bar', '_*-/9090', '?---$$$$', s, 6666].each do |token|
      post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                               :app_id => @application.id,
                                                               :token => token

      assert_equal 200, last_response.status
    end
  end

  test 'handle the access tokens with dots .' do

    token = "hello.xml.xml"

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => token

    assert_equal 200, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status

    node = xml.at('oauth_access_tokens/oauth_access_token')
    assert_equal 1, node.count
    assert_equal token, node.content
    assert_equal'-1', node.attribute('ttl').value

    get "/services/#{@service.id}/oauth_access_tokens/#{token}.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)
    assert_equal @application.id, doc.at('app_id').content

    delete "/services/#{@service.id}/oauth_access_tokens/#{token}.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status

    get "/services/#{@service.id}/oauth_access_tokens/#{token}.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                           :code    => 'access_token_invalid',
                           :message => "access_token \"#{token}\" is invalid: expired or never defined"


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


  end

  # TODO: test correct but different service_id with correct but other provider_id
  test 'CR(-)D with invalid service' do
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => 'INVALID-KEY',
                                                             :app_id => @application.id,
                                                             :token => 'TOKEN'
    assert_equal 403, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => 'INVALID-KEY'
    assert_equal 403, last_response.status

    delete "/services/#{@service.id}/oauth_access_tokens/VALID-TOKEN.xml",
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

  test 'reusing an access token that is already in use fails, unless it is for a different service' do

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

  test 'reusing an expired access token is fine' do

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => '666',
                                                             :ttl => '1'
    assert_equal 200, last_response.status

    sleep(2)

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => '666',
                                                             :ttl => 1
    assert_equal 200, last_response.status


  end


  test 'test that tokens of different application do not get mixed' do

    application2 = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)


    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 666

    assert_equal 200, last_response.status

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 667

    assert_equal 200, last_response.status

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => application2.id,
                                                             :token => 668

    assert_equal 200, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    node = xml.search('oauth_access_tokens/oauth_access_token')

    assert_equal 2, node.count
    assert_equal '666', node[0].content
    assert_equal '-1', node[1].attribute('ttl').value
    assert_equal '667', node[1].content
    assert_equal '-1', node[1].attribute('ttl').value

    get "/services/#{@service.id}/applications/#{application2.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    node = xml.search('oauth_access_tokens/oauth_access_token')

    assert_equal 1, node.count
    assert_equal '668', node[0].content
    assert_equal '-1', node[0].attribute('ttl').value

  end

  test 'perfomance test of setting token' do

    t = Time.now

    100.times do |cont|

       post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                                 :app_id => @application.id,
                                                                 :token => "token-#{cont}"

    end

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    elapsed = Time.now-t

    assert_equal 200, last_response.status
    assert_equal 100, xml.at('oauth_access_tokens').element_children.size

    assert elapsed < 1.0, "Perfomance test failed, took #{elapsed}s to associate 500 access tokens"

  end

  test 'checking read operations consistency' do
    # Create
    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'valid-token1',
                                                             :ttl => '100'
    assert_equal 200, last_response.status

    post "/services/#{@service.id}/oauth_access_tokens.xml", :provider_key => @provider_key,
                                                             :app_id => @application.id,
                                                             :token => 'valid-token2'
    assert_equal 200, last_response.status

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    node = xml.search('oauth_access_tokens/oauth_access_token')

    assert_equal 2, node.count

    ## order does not matter
    if node[0].content=='valid-token1'
      assert_equal 'valid-token1', node[0].content
      assert_equal 100, node[0].attribute('ttl').value.to_i
      assert_equal 'valid-token2', node[1].content
      assert_equal -1, node[1].attribute('ttl').value.to_i
    else
      assert_equal 'valid-token1', node[1].content
      assert_equal 100, node[1].attribute('ttl').value.to_i
      assert_equal 'valid-token2', node[0].content
      assert_equal -1, node[0].attribute('ttl').value.to_i
    end

    get "/services/#{@service.id}/oauth_access_tokens/valid-token1.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)
    assert_equal @application.id, doc.at('app_id').content

    get "/services/#{@service.id}/oauth_access_tokens/valid-token2.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)
    assert_equal @application.id, doc.at('app_id').content

    delete "/services/#{@service.id}/oauth_access_tokens/valid-token1.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status

    get "/services/#{@service.id}/oauth_access_tokens/valid-token1.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'access_token_invalid',
                          :message => 'access_token "valid-token1" is invalid: expired or never defined'


    get "/services/#{@service.id}/oauth_access_tokens/valid-token2.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)
    assert_equal @application.id, doc.at('app_id').content

    get "/services/#{@service.id}/applications/#{@application.id}/oauth_access_tokens.xml",
        :provider_key => @provider_key

    assert_equal 200, last_response.status
    node = xml.search('oauth_access_tokens/oauth_access_token')

    assert_equal 1, node.count
    assert_equal 'valid-token2', node[0].content
    assert_equal '-1', node[0].attribute('ttl').value
  end

  # TODO: more test covering multiservice cases (there is only one right now)

  private

  def xml
    Nokogiri::XML(last_response.body)
  end

end

