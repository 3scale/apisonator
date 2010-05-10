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
end
