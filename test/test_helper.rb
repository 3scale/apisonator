require'simplecov'
SimpleCov.start

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

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
  config.redis.db = 2
end

class Test::Unit::TestCase
  include ThreeScale
  include ThreeScale::Backend
  include ThreeScale::Backend::Configurable
  extend TestHelpers::HumanTestNames
end
