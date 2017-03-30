if ThreeScale::Backend.configuration.saas
  # SaaS-specific dependencies
  require '3scale/backend/statsd'
  require '3scale/backend/experiment'
  require '3scale/backend/log_request_storage'
  require '3scale/backend/use_cases/cubert_service_management_use_case'
  require '3scale/backend/transactor/log_request_job'
  require '3scale/backend/saas_stats'
end
