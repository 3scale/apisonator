require 'rubygems'
require 'test/unit'
require 'rack/test'

$:.unshift(File.dirname(__FILE__) + '/../lib')

require '3scale/backend/application'

class Test::Unit::TestCase
  include ThreeScale::Backend
  include Rack::Test::Methods
  
  def app
    Application
  end
end
