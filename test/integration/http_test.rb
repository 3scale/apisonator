require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class HTTPTest < Test::Unit::TestCase
  include TestHelpers::HTTP
  include TestHelpers::Integration

  test_post '/transactions.xml'
end
