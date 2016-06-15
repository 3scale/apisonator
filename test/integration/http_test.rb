require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class HTTPTest < Test::Unit::TestCase
  include TestHelpers::HTTP
  include TestHelpers::Integration

  test_post '/transactions.xml'
  test_post '/services/123/oauth_access_tokens.xml'
end
