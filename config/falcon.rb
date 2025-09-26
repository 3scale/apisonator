#!/usr/bin/env falcon host
# frozen_string_literal: true

require 'falcon/environment/rack'
require 'falcon/environment/supervisor'
require '3scale/backend/manifest'

HOSTNAME = 'listener'

service HOSTNAME do
  include Falcon::Environment::Rack

  rackup_path 'config.ru'

  ipc_path '/tmp/apisonator.ipc'

  preload '../lib/3scale/prometheus_server.rb'

  manifest = ThreeScale::Backend::Manifest.report
  count manifest[:server_model][:workers].to_i

  port = ENV.fetch("FALCON_PORT", 3001).to_i
  host = ENV.fetch("FALCON_IP", "0.0.0.0")
  endpoint Async::HTTP::Endpoint
             .parse("http://#{host}:#{port}")
             .with(protocol: Async::HTTP::Protocol::HTTP11)
end

service 'supervisor' do
  include Falcon::Environment::Supervisor

  ipc_path '/tmp/apisonator_supervisor.ipc'
end
