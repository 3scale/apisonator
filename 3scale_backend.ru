$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'rubygems'
require '3scale/backend'

run ThreeScale::Backend::Application
