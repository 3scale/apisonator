require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AllowMethodsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  class App < Sinatra::Base
    register ThreeScale::Backend::AllowMethods

    get '/get' do; end

    get '/get-and-put' do; end
    put '/get-and-put' do; end

    get '/get/:this' do; end

    get '/redundant' do; end
    get '/reduntant' do; end
  end

  def app
    App.new
  end

  test 'OPTIONS to defined route responds with list of allowed methods' do
    request '/get', :method => 'OPTIONS'
    assert_equal 200,   last_response.status
    assert_equal 'GET', last_response.headers['Allow']
    
    request '/get-and-put', :method => 'OPTIONS'
    assert_equal 200,        last_response.status
    assert_equal 'GET, PUT', last_response.headers['Allow']
  end

  test 'OPTIONS works for routes with placeholders' do
    request '/get/that', :method => 'OPTIONS'
    assert_equal 200,   last_response.status
    assert_equal 'GET', last_response.headers['Allow']
  end

  test 'OPTIONS lists each method only once' do
    request '/redundant', :method => 'OPTIONS'
    assert_equal 200,   last_response.status
    assert_equal 'GET', last_response.headers['Allow']
  end
end
