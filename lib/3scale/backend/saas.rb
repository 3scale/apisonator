if ThreeScale::Backend.configuration.saas
  # SaaS-specific dependencies
  require '3scale/backend/statsd'
  require '3scale/backend/experiment'
  require '3scale/backend/request_logs'
  require '3scale/backend/transactor/log_request_job'
  require '3scale/backend/saas_stats'
end
