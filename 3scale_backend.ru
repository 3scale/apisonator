$:.unshift(::File.join(::File.dirname(__FILE__), 'lib'))

require 'rubygems'
require '3scale/backend'
require 'rack/fiber_pool'

# TODO: roll my own fiber pool, this one has no tests, therefore it's broken.
use Rack::FiberPool
run ThreeScale::Backend::Application
