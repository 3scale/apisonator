require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StatusTest < Test::Unit::TestCase
  include TestHelpers::Integration

  def test_check
    get '/check.txt'
    assert_equal 200, last_response.status
  end

  def status_check
    get '/status'
    assert_equal 200, last_response.status
  end
end
