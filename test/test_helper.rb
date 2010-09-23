$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'rubygems'
require 'test/unit'
require 'fakefs/safe'
require 'mocha'
require 'nokogiri'
require 'rack/test'
require 'resque_unit'
require 'timecop'

require '3scale/backend'

# Require test helpers.
Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }

ThreeScale::Backend.configure do |config|
  # so I don't accidentally access s3
  config.aws.access_key_id     = 'test_access_key_id'
  config.aws.secret_access_key = 'test_secret_access_key'
 
  config.redis.db              = 2
end

class Test::Unit::TestCase
  include ThreeScale
  include ThreeScale::Backend
  include ThreeScale::Backend::Configurable

  extend TestHelpers::HumanTestNames
end
