# Configuration

Apisonator has some options that can be configured using a configuration file.
When using container images built from the `openshift` directory, we can tune
the same parameters using environment variables. This document describes those
variables.

- [Redis data storage](#redis-data-storage)
- [Redis queues](#redis-queues)
- [Integration with Porta](#integration-with-porta)
- [Logging](#logging)
- [Prometheus metrics](#prometheus-metrics)
- [Feature flags](#feature-flags)
- [Async](#async)
- [Performance](#performance)
- [Cron](#cron)
- [Analytics](#analytics)
- [External error reporting](#external-error-reporting)

## Redis data storage

###  CONFIG_REDIS_PROXY

- Redis URL for the data DB.
- Optional. Defaults to "redis://localhost:22121".
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_REDIS_SENTINEL_HOSTS

- URL of Redis sentinels.
- Optional. Required only when using a Redis cluster with sentinels.
- Applies to: listener, worker, cron.
- Format: list of URLs separated by ",".

###  CONFIG_REDIS_SENTINEL_ROLE

- Asks the sentinel for the URL of the master or a slave.
- Optional. Defaults to master. Applies only when using a Redis cluster with
sentinels.
- Applies to: listener, worker, cron.
- Format: master or slave.

###  CONFIG_REDIS_CONNECT_TIMEOUT

- Connect timeout.
- Optional. Defaults to 5.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

###  CONFIG_REDIS_READ_TIMEOUT

- Read timeout.
- Optional. Defaults to 3.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

###  CONFIG_REDIS_WRITE_TIMEOUT

- Write timeout.
- Optional. Defaults to 3.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_REDIS_MAX_CONNS

- Max number of connections.
- Optional. Defaults to 10.
- Applies to: listener, worker, cron.
- Format: integer (seconds).


## Redis queues

### CONFIG_QUEUES_MASTER_NAME

- Redis URL for the queues DB.
- Required when `RACK_ENV` is not "test" or "development". Defaults to
"redis://localhost:6379" in those 2 environments.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_QUEUES_SENTINEL_HOSTS

- URL of Redis sentinels.
- Optional. Required only when using a Redis cluster with sentinels.
- Applies to: listener, worker, cron.
- Format: list of URLs separated by ",".

### CONFIG_QUEUES_SENTINEL_ROLE

- Asks the sentinel for the URL of the master or a slave.
- Optional. Defaults to master. Applies only when using a Redis cluster with
sentinels.
- Applies to: listener, worker, cron.
- Format: master or slave.

### CONFIG_QUEUES_CONNECT_TIMEOUT

- Connect timeout.
- Optional. Defaults to 5.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_READ_TIMEOUT

- Read timeout.
- Optional. Defaults to 3.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_WRITE_TIMEOUT

- Write timeout.
- Optional. Defaults to 3.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_MAX_CONNS

- Max number of connections.
- Optional. Defaults to 10.
- Applies to: listener, worker, cron.
- Format: integer (seconds).


## Integration with Porta

### CONFIG_INTERNAL_API_USER

- The user needed when sending requests to the internal API.
- Required when `RACK_ENV` is "production", optional otherwise.
- Applies to: listener.
- Format: string.

### CONFIG_INTERNAL_API_PASSWORD

- The password needed when sending requests to the internal API.
- Required when `RACK_ENV` is "production", optional otherwise.
- Applies to: listener.
- Format: string.

### CONFIG_EVENTS_HOOK

- Webhook that Apisonator uses to send events to Porta.
- Required. If not provided, certain features like alerting will not work.
- Applies to: worker.
- Format: string.

### CONFIG_EVENTS_HOOK_SHARED_SECRET

- Password needed to authenticate against the webhook that Apisonator uses to
send events to Porta.
- Required. If not provided, certain features like alerting will not work.
- Applies to: worker.
- Format: string.

### CONFIG_MASTER_SERVICE_ID

- The service ID of the master account in Porta.
- Optional. If not provided, Apisonator does not report metrics to the master
account of Porta.
- Applies to: listener, worker.
- Format: string.

### CONFIG_MASTER_METRICS_TRANSACTIONS

- Name of the metric configured in the master account of Porta to track the
number of report calls. Applies only when `CONFIG_MASTER_SERVICE_ID` is set.
- Optional. Defaults to "transactions".
- Applies to: listener.
- Format: string.

### CONFIG_MASTER_METRICS_TRANSACTIONS_AUTHORIZE

- Name of the metric configured in the master account of Porta to track the
number of authorize calls. Applies only when `CONFIG_MASTER_SERVICE_ID` is set.
- Optional. Defaults to "transactions/authorize".
- Applies to: listener.
- Format: string.


## Logging

### CONFIG_LOG_PATH

- Log path to write logs that are not request logs, like some kind of warnings.
- Optional. Defaults to /dev/stdout.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_REQUEST_LOGGERS

- The format for request logs.
- Optional. Defaults to "text".
- Applies to: listener.
- Format: the options are "text", "json", and "text,json". The last one will
print the logs in both formats.

### CONFIG_WORKERS_LOG_FILE

- Log path to write job logs (runtime, type of job, etc.)
- Optional. Defaults to /dev/stdout.
- Applies to: worker.
- Format: string.

### CONFIG_WORKERS_LOGGER_FORMATTER

- The format for the worker logs.
- Optional. Defaults to "text".
- Applies to: worker.
- Format: the options are "text" and "json".


## Prometheus metrics

### CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED

- Enables prometheus metrics on the listener.
- Optional. Defaults to false.
- Applies to: listener.
- Format: true or false.

### CONFIG_LISTENER_PROMETHEUS_METRICS_PORT

- Port of the Prometheus metrics server of the listener.
- Optional. Defaults to 9394.
- Applies to: listener.
- Format: integer.

### CONFIG_WORKER_PROMETHEUS_METRICS_ENABLED

- Enables prometheus metrics on the worker.
- Optional. Defaults to false.
- Applies to: worker.
- Format: true or false.

### CONFIG_WORKER_PROMETHEUS_METRICS_PORT

- Port of the Prometheus metrics server of the worker.
- Optional. Defaults to 9394.
- Applies to: worker.
- Format: integer.


## Feature flags

### CONFIG_SAAS

- Enables certain features that are only useful for 3scale SaaS.
- Optional. Defaults to false.
- Applies to: listener, worker, cron.
- Format: true or false.

### CONFIG_LEGACY_REFERRER_FILTERS

- Selects the implementation of the referrer filter validator. When set to true,
the validator behaves like an old version of the filter. This should only be
used in Apisonator instances witch customers that rely on that behaviour.
- Optional. Defaults to false.
- Applies to: listener.
- Format: true or false.


## Async

### CONFIG_REDIS_ASYNC

- Enables the [async mode](async.md).
- Optional. Defaults to false.
- Applies to: listener, worker, cron.
- Format: true or false.

### CONFIG_ASYNC_WORKER_MAX_CONCURRENT_JOBS

- Max number of jobs in the reactor.
- Optional. Defaults to 20. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: integer.

### CONFIG_ASYNC_WORKER_MAX_PENDING_JOBS

- Max number of jobs in memory pending to be added to the reactor.
- Optional. Defaults to 100. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: integer.

### CONFIG_ASYNC_WORKER_WAIT_SECONDS_FETCHING

- Seconds to wait before fetching more jobs when the number of jobs
in memory has reached max_pending_jobs.
- Optional. Defaults to 0.01. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: float (in seconds).


## Performance

### CONFIG_NOTIFICATION_BATCH

- Apisonator creates NotifyJobs to update the "transactions" and
"transactions/authorize" metrics. This env defines how many updates include on
each job.
- Optional. Defaults to 10000.
- Applies to: listener.
- Format: integer.

### LISTENER_WORKERS

- Number of worker processes of the listener.
- Optional. Defaults to the number of CPUs * 8.
- Applies to: listener.
- Format: integer.

### PUMA_WORKERS

- Same as `LISTENER_WORKERS`.


## Cron

### RESCHEDULE_JOBS_FREQ

- Frequency of the task that reschedules failed jobs.
- Optional. Defaults to 300.
- Applies to: cron.
- Format: integer (seconds).

### DELETE_STATS_FREQ

- How often to delete the stats of deleted services.
- Optional. Defaults to 86400 (one day).
- Applies to: cron.
- Format: integer (seconds).


## Analytics

### CONFIG_CAN_CREATE_EVENT_BUCKETS

- Allows the listener to create temporary buckets that contain the stats keys
that were updated in the last few minutes. This is useful to be able to export
the latest updates to external analytics systems.
- Optional. Defaults to false. To enable this feature, this env needs to be set
to true, but it also needs to be enabled using a rake task:
`stats:buckets:enable`. This feature can only be enabled when
`CONFIG_SAAS=true`.
- Applies to: worker.
- Format: true or false.

### CONFIG_STATS_BUCKET_SIZE

- How many seconds of changes to store on each bucket when
`CONFIG_CAN_CREATE_EVENT_BUCKETS=true`.
- Optional. Defaults to 5. This only applies when
`CONFIG_CAN_CREATE_EVENT_BUCKETS=true`.
- Applies to: worker.
- Format: integer.

### CONFIG_KINESIS_STREAM_NAME

- Kinesis stream name.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_KINESIS_REGION

- Kinesis stream region.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_AWS_ACCESS_KEY_ID

- AWS access key to authenticate with Kinesis.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_AWS_SECRET_ACCESS_KEY

- AWS secret access key to authenticate with Kinesis and Redshift.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_REDSHIFT_HOST

- Redshift host.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_REDSHIFT_PORT

- Redshift port.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: integer.

### CONFIG_REDSHIFT_DBNAME

- Redshift database name.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_REDSHIFT_USER

- Redshift user.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.

### CONFIG_REDSHIFT_PASSWORD

- Redshift user.
- Optional. Only applies when the analytics system is enabled.
- Applies to: worker.
- Format: string.


## Environment

### RACK_ENV

- Used to enable/disable some features, mainly it's used to expose some
functions that are only useful when running the test suite.
- Optional: defaults to "development".
- Applies to: listener, worker, cron.
- Format: "development", "test", "production". When set to any other value, it
will act as "development". Also, the error reporting service might use this to
distinguish between "production" and "staging" for example.


## External error reporting

### CONFIG_HOPTOAD_SERVICE

- External error reporting service to use.
- Optional. Does not report errors by default.
- Applies to: listener, worker, cron.
- Format: "bugsnag" or "airbrake".

### CONFIG_HOPTOAD_API_KEY

- The API key used to authenticate against the service configured with
`CONFIG_HOPTOAD_SERVICE`.
- Optional. Empty by default.
- Applies to: listener, worker, cron.
- Format: string.
