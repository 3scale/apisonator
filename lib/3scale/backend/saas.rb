if ThreeScale::Backend.configuration.saas
  # SaaS-specific dependencies
  require '3scale/backend/statsd'
  require '3scale/backend/experiment'
  require '3scale/backend/saas_stats'
end
