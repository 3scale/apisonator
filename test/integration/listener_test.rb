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

  def test_invalid_percent_encoding
    # We pass a string and not a hash as a parameter due to
    # the rack-test library performs modifications to the passed values
    # (changes encoding, content-type, etc...) when a hash is passed,
    # and we do not want to have any modifications to the content in this
    # case.
    post '/transactions.xml', 'testparam=value1%'

    assert_equal 400, last_response.status

    node = xml.at('error')
    assert_equal Rack::ExceptionCatcher.const_get(:INVALID_PERCENT_ENCODING_ERR_MSG), node.content
    assert_equal 'bad_request', node['code']
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

  def test_unsupported_end_users_auth
    get '/transactions/authorize.xml', provider_key: 'pk', user_id: '123'
    check_end_users_not_supported_error(last_response)

    get '/transactions/authrep.xml', provider_key: 'pk', user_id: '123'
    check_end_users_not_supported_error(last_response)
  end

  def test_unsupported_end_users_report
    post '/transactions.xml',
         provider_key: 'pk',
         service_id: '42',
         transactions: { 0 => { user_id: '123', usage: { 'hits' => 1 } } }

    check_end_users_not_supported_error(last_response)
  end

  private

  def xml
    Nokogiri::XML(last_response.body)
  end

  def check_end_users_not_supported_error(last_response)
    assert_equal 400, last_response.status
    node = xml.at('error')
    assert_equal 'End-users are no longer supported, do not specify the user_id parameter', node.content
    assert_equal 'end_users_no_longer_supported', node['code']
  end
end
