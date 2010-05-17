ENV['RACK_ENV'] ||= 'test'
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'test/unit'
require 'fakefs/safe'
require 'mocha'
require 'nokogiri'
require 'rack/test'
require 'timecop'

require '3scale/backend'

Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }

class Test::Unit::TestCase
  include ThreeScale::Backend
  include ThreeScale::Backend::Configurable
end

ThreeScale::Backend.configure do |config|
  config.master_provider_key   = 'master'

  # so I don't accidentally access s3
  config.aws.access_key_id     = 'test_access_key_id'
  config.aws.secret_access_key = 'test_secret_access_key'
  
  config.redis.db              = 2
end
