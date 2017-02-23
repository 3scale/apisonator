require_relative 'lib/3scale/backend'

if ThreeScale::Backend.configuration.saas && Airbrake.configuration.api_key
  use Airbrake::Sinatra
end

use ThreeScale::Backend::Logger::Middleware

map "/internal" do
  require_relative 'app/api/api'

  internal_api = ThreeScale::Backend::API::Internal.new(
    username: ThreeScale::Backend.configuration.internal_api.user,
    password: ThreeScale::Backend.configuration.internal_api.password,
    allow_insecure: !ThreeScale::Backend.production?
  )

  use Rack::Auth::Basic do |username, password|
    internal_api.helpers.check_password username, password
  end if internal_api.helpers.credentials_set?

  run internal_api
end

run ThreeScale::Backend::Listener.new
