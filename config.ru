ENV['BACKEND_COMPONENT'] = 'listener'

require_relative 'lib/3scale/bundler_shim'
require '3scale/backend/rack'

ThreeScale::Backend::Rack.run self
