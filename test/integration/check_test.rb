require File.dirname(__FILE__) + '/../test_helper'

class CheckTest < Test::Unit::TestCase
  include TestHelpers::Integration

  def test_check
    get '/check.txt'
    assert_equal 200, last_response.status
  end
end
