require'simplecov'
SimpleCov.start

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

## WTF: now I need the require before the test, otherwise the resque_unit does not overwrite resque methods. Which
## makes sense. However, how come this ever worked before? no idea. If using resque_unit 0.2.7 I can require 
## test/unit after. 
require '3scale/backend'

require 'test/unit'
require 'fakefs/safe'
require 'mocha/setup'
require 'nokogiri'
require 'rack/test'
require 'resque_unit'
require 'timecop'

# Require test helpers.
Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }

ThreeScale::Backend.configure do |config|
  unless config.redis.servers.nil? || (config.redis.servers.length == 1 && config.redis.servers.first.to_s == "127.0.0.1:6379")
    raise "test run not allowed when redis is not localhost"
  end
  config.redis.db = 2
  config.stats.bucket_size = 5 
end

ThreeScale::Backend.configuration

## to initilize the worker class variables for those cases that worker is called without creating
## a worker first, only happens in test environment
ThreeScale::Backend::Worker.new

class Test::Unit::TestCase
  include ThreeScale
  include ThreeScale::Backend
  include ThreeScale::Backend::Configurable
  extend TestHelpers::HumanTestNames
end
