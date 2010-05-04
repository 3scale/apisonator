$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'rubygems'
require '3scale/backend/application'

run ThreeScale::Backend::Application
