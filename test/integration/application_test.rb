require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase
  include TestHelpers::Integration

  def test_on_invalid_path_responds_with_404
    async_post '/foo.html' do |response|
      assert_equal 404, response.status
    end
  end

  def test_on_invalid_http_method_responds_with_404
    async_get '/transactions.xml' do |response|
      assert_equal 404, response.status
    end
  end
end
