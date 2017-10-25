require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ListenerTest < Test::Unit::TestCase
  include TestHelpers::Integration

  UnexpectedError = Class.new(RuntimeError)
  ExpectedError   = Class.new(Error)

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

  def test_missing_required_parameters
    post '/services/123/oauth_access_tokens.xml', :provider_key => 'foo' # no :token
    assert_equal 422, last_response.status

    node = xml.at('error')
    assert_equal 'missing required parameters', node.content
    assert_equal 'required_params_missing', node['code']
  end

  def test_malformed_hash_param
    get '/transactions/authorize.xml', :provider_key => 'abc',
                                       :usage => { '' => 1, 'hits' => 1 }

    assert_equal 400, last_response.status

    node = xml.at('error')
    assert_equal 'request contains syntax errors, should not be repeated without modification',
                 node.content
    assert_equal 'bad_request', node['code']
  end

  private

  def xml
    Nokogiri::XML(last_response.body)
  end
end
