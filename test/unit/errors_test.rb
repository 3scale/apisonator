require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ErrorsTest < Test::Unit::TestCase
  def test_xml_serialization
    exception = ProviderKeyInvalid.new('moo')

    doc = Nokogiri::XML(exception.to_xml)

    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 'provider key "moo" is invalid', error.content
  end

  test 'code' do
    assert_equal 'application_not_found', ApplicationNotFound.code
    assert_equal 'application_not_found', ApplicationNotFound.new('boo').code
  end

  test 'message of ApplicationNotFound' do
    error = ApplicationNotFound.new('boo')
    assert_equal 'application with id="boo" was not found', error.message
  end

  test 'http code of ApplicationNotFound' do
    assert_equal 404, ApplicationNotFound.new('boo').http_code
  end

  test 'message of ProviderKeyInvalid' do
    error = ProviderKeyInvalid.new('foo')
    assert_equal 'provider key "foo" is invalid', error.message
  end

  test 'http code of ProviderKeyInvalid' do
    assert_equal 403, ProviderKeyInvalid.new('foo').http_code
  end

  test 'message of UserKeyInvalid' do
    error = UserKeyInvalid.new('foo')
    assert_equal 'user key "foo" is invalid', error.message
  end

  def test_message_of_application_key_invalid_when_the_key_is_blank
    error = ApplicationKeyInvalid.new(nil)
    assert_equal %(application key is missing), error.message

    error = ApplicationKeyInvalid.new('')
    assert_equal %(application key is missing), error.message
  end

  def test_message_of_application_key_invalid_when_the_key_is_not_blank
    error = ApplicationKeyInvalid.new('foo')
    assert_equal %(application key "foo" is invalid), error.message
  end

  def test_message_of_metric_invalid
    error = MetricInvalid.new('foos')
    assert_equal 'metric "foos" is invalid', error.message
  end

  def test_message_of_usage_value_invalid_when_the_value_is_blank
    error = UsageValueInvalid.new('hits', nil)
    assert_equal %(usage value for metric "hits" can not be empty), error.message

    error = UsageValueInvalid.new('hits', '')
    assert_equal %(usage value for metric "hits" can not be empty), error.message
  end

  test 'message of UsageValueInvalid when the value is not blank' do
    error = UsageValueInvalid.new('hits', 'really a lot')
    assert_equal %(usage value "really a lot" for metric "hits" is invalid), error.message
  end

  test 'message of ApplicationNotActive' do
    error = ApplicationNotActive.new
    assert_equal 'application is not active', error.message
  end

  test 'message of LimitsExceeded' do
    error = LimitsExceeded.new
    assert_equal 'usage limits are exceeded', error.message
  end

  test 'message of ReferrerNotAllowed when the value is blank' do
    error = ReferrerNotAllowed.new(nil)
    assert_equal 'referrer is missing', error.message
  end

  test 'message of ReferrerNotAllowed when the value is not blank' do
    error = ReferrerNotAllowed.new('foo.example.org')
    assert_equal 'referrer "foo.example.org" is not allowed', error.message
  end
end
