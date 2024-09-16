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
- [OpenTelemetry](#opentelemetry)
- [Feature flags](#feature-flags)
- [Async](#async)
- [Performance](#performance)
- [Cron](#cron)
- [Analytics](#analytics)
- [External error reporting](#external-error-reporting)

## Redis data storage

###  CONFIG_REDIS_PROXY

- Redis URL for the data DB.
- Optional. Defaults to `redis://localhost:6379`.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_REDIS_USERNAME

- Redis user name
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_REDIS_PASSWORD

- Redis password
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_REDIS_SSL

- Whether use SSL to connect to Redis
- Optional. Defaults to not set
- Will be considered `true` when the URL schema is `rediss`
- Applies to: listener, worker, cron.
- Format: `true` or `false`.

###  CONFIG_REDIS_CA_FILE

- Certification authority to validate Redis server TLS connections with
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

###  CONFIG_REDIS_CERT

- The path to the client SSL certificate
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

###  CONFIG_REDIS_PRIVATE_KEY

- The path to the client SSL private key
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

###  CONFIG_REDIS_SENTINEL_HOSTS

- URL of Redis sentinels.
- Optional. Required only when using a Redis cluster with sentinels.
- Applies to: listener, worker, cron.
- Format: list of URLs separated by `,`.

### CONFIG_REDIS_SENTINEL_USERNAME

- Sentinels user name
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_REDIS_SENTINEL_PASSWORD

- Sentinels password
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_REDIS_SENTINEL_ROLE

- Asks the sentinel for the URL of the master or a slave.
- Optional. Defaults to `master`. Applies only when using a Redis cluster with
sentinels.
- Applies to: listener, worker, cron.
- Format: `master` or `slave`.

###  CONFIG_REDIS_CONNECT_TIMEOUT

- Connect timeout.
- Optional. Defaults to `5`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

###  CONFIG_REDIS_READ_TIMEOUT

- Read timeout.
- Optional. Defaults to `3`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

###  CONFIG_REDIS_WRITE_TIMEOUT

- Write timeout.
- Optional. Defaults to `3`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_REDIS_MAX_CONNS

- Max number of connections.
- Optional. Defaults to `10`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).


## Redis queues

### CONFIG_QUEUES_MASTER_NAME

- Redis URL for the queues DB.
- Required when `RACK_ENV` is not `test` or `development`. Defaults to
`redis://localhost:6379` in those 2 environments.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_QUEUES_USERNAME

- Redis user name
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_QUEUES_PASSWORD

- Redis password
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

###  CONFIG_QUEUES_SSL

- Whether use SSL to connect to Redis
- Optional. Defaults to not set
- Will be considered `true` when the URL schema is `rediss`
- Applies to: listener, worker, cron.
- Format: `true` or `false`.

###  CONFIG_QUEUES_CA_FILE

- Certification authority certificate Redis should trust to accept TLS connections
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

###  CONFIG_QUEUES_CERT

- User certificate to connect to Redis through TLS
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

###  CONFIG_QUEUES_PRIVATE_KEY

- User key to connect to Redis through TLS
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: path to file as string.

### CONFIG_QUEUES_SENTINEL_HOSTS

- URL of Redis sentinels.
- Optional. Required only when using a Redis cluster with sentinels.
- Applies to: listener, worker, cron.
- Format: list of URLs separated by `,`.

### CONFIG_QUEUES_SENTINEL_USERNAME

- Sentinels user name
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_QUEUES_SENTINEL_PASSWORD

- Sentinels password
- Optional. Defaults to not set.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_QUEUES_SENTINEL_ROLE

- Asks the sentinel for the URL of the master or a slave.
- Optional. Defaults to `master`. Applies only when using a Redis cluster with
sentinels.
- Applies to: listener, worker, cron.
- Format: `master` or `slave`.

### CONFIG_QUEUES_CONNECT_TIMEOUT

- Connect timeout.
- Optional. Defaults to `5`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_READ_TIMEOUT

- Read timeout.
- Optional. Defaults to `3`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_WRITE_TIMEOUT

- Write timeout.
- Optional. Defaults to `3`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).

### CONFIG_QUEUES_MAX_CONNS

- Max number of connections.
- Optional. Defaults to `10`.
- Applies to: listener, worker, cron.
- Format: integer (seconds).


## Integration with Porta

### CONFIG_INTERNAL_API_USER

- The user needed when sending requests to the internal API.
- Required when `RACK_ENV` is `production`, optional otherwise.
- Applies to: listener.
- Format: string.

### CONFIG_INTERNAL_API_PASSWORD

- The password needed when sending requests to the internal API.
- Required when `RACK_ENV` is `production`, optional otherwise.
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
- Optional. Defaults to `transactions`.
- Applies to: listener.
- Format: string.

### CONFIG_MASTER_METRICS_TRANSACTIONS_AUTHORIZE

- Name of the metric configured in the master account of Porta to track the
number of authorize calls. Applies only when `CONFIG_MASTER_SERVICE_ID` is set.
- Optional. Defaults to `transactions/authorize`.
- Applies to: listener.
- Format: string.


## Logging

### CONFIG_LOG_PATH

- Log path to write logs that are not request logs, like some kind of warnings.
- Optional. Defaults to `/dev/stdout`.
- Applies to: listener, worker, cron.
- Format: string.

### CONFIG_REQUEST_LOGGERS

- The format for request logs.
- Optional. Defaults to `text`.
- Applies to: listener.
- Format: the options are `text`, `json`, and `text,json`. The last one will
print the logs in both formats.

### CONFIG_WORKERS_LOG_FILE

- Log path to write job logs (runtime, type of job, etc.)
- Optional. Defaults to `/dev/stdout`.
- Applies to: worker.
- Format: string.

### CONFIG_WORKERS_LOGGER_FORMATTER

- The format for the worker logs.
- Optional. Defaults to `text`.
- Applies to: worker.
- Format: the options are `text` and `json`.


## Prometheus metrics

### CONFIG_LISTENER_PROMETHEUS_METRICS_ENABLED

- Enables prometheus metrics on the listener.
- Optional. Defaults to `false`.
- Applies to: listener.
- Format: `true` or `false`.

### CONFIG_LISTENER_PROMETHEUS_METRICS_PORT

- Port of the Prometheus metrics server of the listener.
- Optional. Defaults to `9394`.
- Applies to: listener.
- Format: integer.

### CONFIG_WORKER_PROMETHEUS_METRICS_ENABLED

- Enables prometheus metrics on the worker.
- Optional. Defaults to `false`.
- Applies to: worker.
- Format: `true` or `false`.

### CONFIG_WORKER_PROMETHEUS_METRICS_PORT

- Port of the Prometheus metrics server of the worker.
- Optional. Defaults to `9394`.
- Applies to: worker.
- Format: integer.

## OpenTelemetry

### CONFIG_OPENTELEMETRY_ENABLED

- Enables OpenTelemetry instrumentation
- Optional. Defaults to `false`.
- Applies to: listener.
- Format: `true` or `false`.

## Feature flags

### CONFIG_LEGACY_REFERRER_FILTERS

- Selects the implementation of the referrer filter validator. When set to true,
the validator behaves like an old version of the filter. This should only be
used in Apisonator instances witch customers that rely on that behaviour.
- Optional. Defaults to `false`.
- Applies to: listener.
- Format: `true` or `false`.


## Async

### CONFIG_REDIS_ASYNC

- Enables the [async mode](async.md).
- Optional. Defaults to `false`.
- Applies to: listener, worker, cron.
- Format: `true` or `false`.

### CONFIG_ASYNC_WORKER_MAX_CONCURRENT_JOBS

- Max number of jobs in the reactor.
- Optional. Defaults to `20`. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: integer.

### CONFIG_ASYNC_WORKER_MAX_PENDING_JOBS

- Max number of jobs in memory pending to be added to the reactor.
- Optional. Defaults to `100`. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: integer.

### CONFIG_ASYNC_WORKER_WAIT_SECONDS_FETCHING

- Seconds to wait before fetching more jobs when the number of jobs
in memory has reached max_pending_jobs.
- Optional. Defaults to `0.01`. Applies only when `CONFIG_REDIS_ASYNC=true`.
- Applies to: worker.
- Format: float (in seconds).


## Performance

### CONFIG_NOTIFICATION_BATCH

- Apisonator creates NotifyJobs to update the `transactions` and
`transactions/authorize metrics`. This env defines how many updates include on
each job.
- Optional. Defaults to `10000`.
- Applies to: listener.
- Format: integer.

### LISTENER_WORKERS

- Number of worker processes of the listener.
- Optional. Defaults to the `number of CPUs * 8`.
- Applies to: listener.
- Format: integer.

### PUMA_WORKERS

- Same as `LISTENER_WORKERS`.


## Cron

### RESCHEDULE_JOBS_FREQ

- Frequency of the task that reschedules failed jobs.
- Optional. Defaults to `300`.
- Applies to: cron.
- Format: integer (seconds).

### DELETE_STATS_FREQ

- How often to delete the stats of deleted services.
- Optional. Defaults to `86400` (one day).
- Applies to: cron.
- Format: integer (seconds).

## Environment

### RACK_ENV

- Used to enable/disable some features, mainly it's used to expose some
functions that are only useful when running the test suite.
- Optional: defaults to `development`.
- Applies to: listener, worker, cron.
- Format: `development`, `test`, `production`. When set to any other value, it
will act as `development`. Also, the error reporting service might use this to
distinguish between `production` and `staging` for example.


## External error reporting

### CONFIG_HOPTOAD_SERVICE

- External error reporting service to use.
- Optional. Does not report errors by default.
- Applies to: listener, worker, cron.
- Format: Only "bugsnag" supported.

### CONFIG_HOPTOAD_API_KEY

- The API key used to authenticate against the service configured with
`CONFIG_HOPTOAD_SERVICE`.
- Optional. Empty by default.
- Applies to: listener, worker, cron.
- Format: string.
