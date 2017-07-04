require 'simplecov' if ENV['TEST_COVERAGE']

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
