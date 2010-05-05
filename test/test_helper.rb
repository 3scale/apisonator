ENV['RACK_ENV'] ||= 'test'
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'test/unit'
require 'rack/test'
require 'fakefs/safe'

require '3scale/backend'

require 'factory_girl'
require File.dirname(__FILE__) + '/factories.rb'

Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }

class Test::Unit::TestCase
  include ThreeScale::Backend
end
