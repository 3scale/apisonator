require '3scale/backend'

use Airbrake::Sinatra if Airbrake.configuration.api_key
use ThreeScale::Backend::Logger::Middleware if ThreeScale::Backend::Server.log

map "/internal" do
  require_relative 'app/api/api'
  use Rack::Auth::Basic do |username, password|
    ThreeScale::Backend::API::Internal.check_password username, password
  end
  run ThreeScale::Backend::API::Internal.new
end

run ThreeScale::Backend::Listener.new
