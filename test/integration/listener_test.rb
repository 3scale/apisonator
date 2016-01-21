require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ListenerTest < Test::Unit::TestCase
  include TestHelpers::Integration

  UnexpectedError = Class.new(RuntimeError)
  ExpectedError   = Class.new(Error)

  TOOBIGSIZE_PARAM = Listener::MAX_PARAM_LENGTH + 1
  TOOBIGSIZE_TOKEN = OAuthAccessTokenStorage::MAXIMUM_TOKEN_SIZE + 1

  def test_big_params_limit_less_or_equal_big_token_limit
    assert TOOBIGSIZE_PARAM <= TOOBIGSIZE_TOKEN
  end

  def test_big_params_in_known_parameter
    get "/transactions/authorize.xml?provider_key=#{'x' * TOOBIGSIZE_PARAM}"
    assert_too_big
  end

  def test_big_params_in_unknown_parameter
    get "/transactions/authrep.xml?unknown_param=#{'x' * TOOBIGSIZE_PARAM}"
    assert_too_big
  end

  def test_big_params_in_key_only
    get "/transactions/authrep.xml?#{'x' * TOOBIGSIZE_PARAM}=1"
    assert_too_big
  end

  def test_big_params_in_body
    post '/transactions.xml', provider_key: '123', some_param: "#{'x' * TOOBIGSIZE_PARAM}"
    assert_too_big
    post '/transactions.xml', provider_key: '123', some_param: "#{'x' * (TOOBIGSIZE_PARAM - 1)}"
    assert_not_too_big
  end

  def test_big_param_returns_error_message
    get "/transactions/authrep.xml?whatever_param=#{'x' * TOOBIGSIZE_PARAM}"
    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'params_too_big', error['code']
    assert_equal 'At least one parameter or its value is too big', error.content
  end

  def test_big_params_request_with_oauth_access_token_storage
    post "/services/#{'x' * TOOBIGSIZE_PARAM}/oauth_access_tokens.xml?token=123"
    assert_too_big
    post "/services/666/oauth_access_tokens.xml?token=#{'x' * TOOBIGSIZE_TOKEN}"
    assert_too_big
    post "/services/666/oauth_access_tokens.xml?token=#{'x' * (TOOBIGSIZE_TOKEN-1)}"
    assert_not_too_big
  end

  def test_big_params_request_with_oauth_access_token_storage_parameter
    get "/transactions/oauth_authorize.xml?provider_key=123&access_token=#{'x' * TOOBIGSIZE_TOKEN}"
    assert_too_big
    get "/transactions/oauth_authorize.xml?provider_key=123&access_token=#{'x' * (TOOBIGSIZE_TOKEN-1)}"
    assert_not_too_big
  end

  def test_big_param_inside_hash_returns_400
    get "/transactions/authorize.xml?bighash[x]=1&bighash[#{'x' * TOOBIGSIZE_PARAM}]=1"
    assert_too_big
    get "/transactions/authorize.xml?okhash[x]=1&okhash[#{'x' * (TOOBIGSIZE_PARAM - 1)}]=1"
    assert_not_too_big
    post '/transactions.xml', provider_key: '123',
      transactions: {0 => {:app_id => '456', :usage => {"#{'x' * TOOBIGSIZE_PARAM}" => 1} }}
    assert_too_big
  end

  def test_big_param_inside_array_returns_400
    get "/transactions/authorize.xml?bigarray[]=x&bigarray[]=#{'x' * TOOBIGSIZE_PARAM}"
    assert_too_big
    get "/transactions/authorize.xml?okarray[]=x&okarray[]=#{'x' * (TOOBIGSIZE_PARAM - 1)}"
    assert_not_too_big
  end

  def test_on_invalid_path_responds_with_404
    post '/foo.html'
    assert_equal 404, last_response.status
  end

  def test_on_invalid_http_method_responds_with_404
    get '/transactions.xml'
    assert_equal 404, last_response.status

    post '/transaction/authorize.xml'
    assert_equal 404, last_response.status
  end

  def test_empty_report
    post '/transactions.xml'
    assert_equal 403, last_response.status
  end

  def test_unexpected_exception_bubbles_through
    Transactor.stubs(:report).raises(UnexpectedError.new('bang!'))
    assert_raise UnexpectedError do
      post '/transactions.xml?transactions[0]=foo2', :provider_key => 'foo'
    end
  end

  def test_expected_exception_is_caught
    Transactor.stubs(:report).raises(ExpectedError.new('bang!'))
    assert_nothing_raised do
      post '/transactions.xml?transactions[0]=foo2', :provider_key => 'foo'
    end
  end

  def test_utf8_exception_is_caught
    Transactor.stubs(:report).raises(ArgumentError.new('invalid byte sequence in UTF-8'))
    assert_nothing_raised do
      post '/transactions.xml?transactions[0]=foo2', :provider_key => 'foo'
    end
  end

  def test_missing_required_parameters
    post '/services/123/oauth_access_tokens.xml', :provider_key => 'foo' # no :token
    assert_equal 422, last_response.status

    node = xml.at('error')
    assert_equal 'missing required parameters', node.content
    assert_equal 'required_params_missing', node['code']
  end

  private

  def xml
    Nokogiri::XML(last_response.body)
  end
end
