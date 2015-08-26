require '3scale/backend'

use Airbrake::Sinatra if Airbrake.configuration.api_key
use ThreeScale::Backend::Logger::Middleware if ThreeScale::Backend::Server.log

map "/internal" do
  use Rack::Auth::Basic do |username, password|
    ThreeScale::Backend::Server.check_password username, password
  end

  run ThreeScale::Backend::API::Internal.new
end

run ThreeScale::Backend::Listener.new
