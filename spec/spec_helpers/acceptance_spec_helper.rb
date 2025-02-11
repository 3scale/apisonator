require_relative '../../app/api/api'

require 'rack/test'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

def response_json
  JSON.parse(last_response.body)
end

def status
  last_response.status
end
alias :response_status :status

def app
  ThreeScale::Backend::API::Internal.new(allow_insecure: true)
end
