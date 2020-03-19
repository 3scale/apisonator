# Prometheus metrics

| Metric                                | Type      | Labels                                                                       | Description                                 |
|---------------------------------------|-----------|------------------------------------------------------------------------------|---------------------------------------------|
| apisonator_listener_response_times    | histogram | request_type(authorize, authrep, report)                                     | Request response times in seconds           |
| apisonator_listener_response_codes    | counter   | request_type(authorize, authrep, report), resp_code(2xx, 403, 404, 409, 5xx) | HTTP status codes returned by the listeners |
| apisonator_worker_job_count           | counter   | type(ReportJob, NotifyJob, etc.)                                             | Number of jobs processed                    |
| apisonator_worker_job_runtime_seconds | histogram | type(ReportJob, NotifyJob, etc.)                                             | How long the jobs take to complete          |
