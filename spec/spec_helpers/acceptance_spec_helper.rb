require_relative '../../app/api/api'

require 'rack/test'
require 'rspec_api_documentation'
require 'rspec_api_documentation/dsl'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

RspecApiDocumentation.configure do |config|
  config.docs_dir = Pathname.new(__FILE__).dirname.join('..', '..', 'docs', 'internal_api')
  config.app = ThreeScale::Backend::API::Internal.new(allow_insecure: true)
end

def response_json
  JSON.parse(response_body)
end
