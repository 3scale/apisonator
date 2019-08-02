# Prometheus metrics

| Metric                                | Description                        | Type      | Labels                           |
|---------------------------------------|------------------------------------|-----------|----------------------------------|
| apisonator_worker_job_count           | Number of jobs processed           | counter   | type(ReportJob, NotifyJob, etc.) |
| apisonator_worker_job_runtime_seconds | How long the jobs take to complete | histogram | type(ReportJob, NotifyJob, etc.) |
