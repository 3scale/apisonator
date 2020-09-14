# Prometheus metrics

| Metric                                          | Type      | Labels                                                                                                       | Description                                              |
|-------------------------------------------------|-----------|--------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| apisonator_listener_response_times              | histogram | request_type(authorize, authrep, report, authorize_oauth, authrep_oauth)                                     | Request response times in seconds                        |
| apisonator_listener_response_codes              | counter   | request_type(authorize, authrep, report, authorize_oauth, authrep_oauth), resp_code(2xx, 403, 404, 409, 5xx) | HTTP status codes returned by the listeners              |
| apisonator_listener_internal_api_response_times | histogram | request_type(services, applications, metrics, usage_limits, etc.)                                            | Response times in seconds for the Internal API endpoints |
| apisonator_listener_internal_api_response_codes | counter   | request_type(services, applications, metrics, usage_limits, etc.), resp_code(2xx, 403, 404, 409, 5xx)        | HTTP status codes returned by the Internal API endpoints |
| apisonator_worker_job_count                     | counter   | type(ReportJob, NotifyJob)                                                                                   | Number of jobs processed                                 |
| apisonator_worker_job_runtime_seconds           | histogram | type(ReportJob, NotifyJob)                                                                                   | How long the jobs take to complete                       |
