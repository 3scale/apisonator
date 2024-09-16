require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry-exporter-otlp'
require '3scale/backend/configuration'

OpenTelemetry::SDK.configure do |c|
  c.service_name = '3scale-backend'
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
end if ThreeScale::Backend.configuration.opentelemetry.enabled
