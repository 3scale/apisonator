if ENV['CODECLIMATE_REPO_TOKEN']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

## WTF: now I need the require before the test, otherwise the resque_unit does
## not overwrite resque methods. Which makes sense. However, how come this ever
## worked before? no idea. If using resque_unit 0.2.7 I can require
## test/unit after.
require '3scale/backend'

require 'test/unit'
require 'mocha/setup'
require 'nokogiri'
require 'rack/test'
require 'resque_unit'
require 'timecop'

# Require test helpers.
Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }

ThreeScale::Backend.configure do |config|
  config.redis.nodes = [
    "127.0.0.1:7379",
    "127.0.0.1:7380",
  ]

  config.stats.bucket_size  = 5
  config.notification_batch = 5

  config.influxdb.database = "backend_test"
end

ThreeScale::Backend.configuration

## to initilize the worker class variables for those cases that worker is called
## without creating a worker first, only happens in test environment
ThreeScale::Backend::Worker.new

def reset_aggregator_prior_bucket!
  ThreeScale::Backend::Stats::Aggregator.send(:prior_bucket=, nil)
end

class Test::Unit::TestCase
  include ThreeScale
  include ThreeScale::Backend
  include ThreeScale::Backend::Configurable
end
