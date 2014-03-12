require File.join(File.dirname(__FILE__), '..', 'lib', '3scale', 'backend.rb')
require 'rack/test'
require 'rspec_api_documentation'
require 'rspec_api_documentation/dsl'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

def set_app(app)
  RspecApiDocumentation.configure do |config|
    config.app = app
  end
end
