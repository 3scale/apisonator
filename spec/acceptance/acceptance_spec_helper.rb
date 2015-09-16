require_relative '../spec_helper'
require_relative '../../app/api/api'

require 'rack/test'
require 'rspec_api_documentation'
require 'rspec_api_documentation/dsl'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

RspecApiDocumentation.configure do |config|
  config.docs_dir = Pathname.new(__FILE__).dirname.join('..', '..', 'docs', 'internal_api')
end

def set_app(app)
  RspecApiDocumentation.configure do |config|
    config.app = app
  end
end

def response_json
  JSON.parse(response_body)
end

