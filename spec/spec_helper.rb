require File.join(File.dirname(__FILE__), '..', 'lib', '3scale', 'backend.rb')
require 'rack/test'
require 'rspec_api_documentation'
require 'rspec_api_documentation/dsl'

def app
  ThreeScale::Backend::Listener
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

RspecApiDocumentation.configure do |config|
  config.app = app
end
