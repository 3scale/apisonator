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

  def test_code
    assert_equal 'application_not_found', ApplicationNotFound.code
    assert_equal 'application_not_found', ApplicationNotFound.new('boo').code
  end

  def test_message_of_application_not_found
    error = ApplicationNotFound.new('boo')
    assert_equal 'application with id="boo" was not found', error.message
  end
  
  def test_message_of_provider_key_invalid
    error = ProviderKeyInvalid.new('foo')
    assert_equal 'provider key "foo" is invalid', error.message
  end

  def test_message_of_application_key_invalid_when_the_key_is_blank
    error = ApplicationKeyInvalid.new(nil)
    assert_equal %Q(application key is missing), error.message
    
    error = ApplicationKeyInvalid.new('')
    assert_equal %Q(application key is missing), error.message
  end
  
  def test_message_of_application_key_invalid_when_the_key_is_not_blank
    error = ApplicationKeyInvalid.new('foo')
    assert_equal %Q(application key "foo" is invalid), error.message
  end
  
  def test_message_of_metric_invalid
    error = MetricInvalid.new('foos')
    assert_equal 'metric "foos" is invalid', error.message
  end
  
  def test_message_of_usage_value_invalid_when_the_value_is_blank
    error = UsageValueInvalid.new('hits', nil)
    assert_equal %Q(usage value for metric "hits" can't be empty), error.message
    
    error = UsageValueInvalid.new('hits', '')
    assert_equal %Q(usage value for metric "hits" can't be empty), error.message
  end
  
  def test_message_of_usage_value_invalid_when_the_value_is_not_blank
    error = UsageValueInvalid.new('hits', 'really a lot')
    assert_equal %Q(usage value "really a lot" for metric "hits" is invalid), error.message
  end

  def test_message_of_application_not_active_error
    error = ApplicationNotActive.new
    assert_equal 'application is not active', error.message
  end
  
  test 'message of LimitsExceeded' do
    error = LimitsExceeded.new
    assert_equal 'usage limits are exceeded', error.message
  end

  test 'message of DomainInvalid when the value is blank' do
    error = DomainInvalid.new(nil)
    assert_equal 'domain is missing', error.message
  end
  
  test 'message of DomainInvalid when the value is not blank' do
    error = DomainInvalid.new('foo.example.org')
    assert_equal 'domain "foo.example.org" is not allowed', error.message
  end
end
