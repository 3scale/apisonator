require File.dirname(__FILE__) + '/../test_helper'

class ErrorsTest < Test::Unit::TestCase
  def test_xml_serialization
    exception = MultipleErrors.new(0 => 'user.invalid_key',
                                   4 => 'user.inactive_contract')

    doc = Nokogiri::XML(exception.to_xml)

    assert_equal 2, doc.search('errors:root error').count

    error_0 = doc.at('errors error[index = "0"]')
    assert_not_nil error_0
    assert_equal 'user.invalid_key', error_0['code']
    assert_equal 'user_key is invalid', error_0.content

    error_4 = doc.at('errors error[index = "4"]')
    assert_not_nil error_4
    assert_equal 'user.inactive_contract', error_4['code']
    assert_equal 'contract is not active', error_4.content
  end
end
