require File.dirname(__FILE__) + '/../test_helper'

class TestAction < ThreeScale::Backend::Action
  def perform(request)
    @request = request
    [200, {}, []]
  end

  attr_reader :request
end

class ActionTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def teardown
    @action = nil
  end

  def app
    @action ||= TestAction.new
  end

  def test_calls_perform_with_request_object
    get '/stuff', :foo => 'bar'

    assert_not_nil         @action.request
    assert_equal '/stuff', @action.request.path_info
    assert_equal 'bar',    @action.request.params['foo']
  end
end
