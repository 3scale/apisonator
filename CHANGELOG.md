# Change Log

Notable changes to Apisonator will be tracked in this document.

## Unreleased

### Changed

- storage_async/async_redis: read all responses in pipelines ([#302](https://github.com/3scale/apisonator/pull/302))
- [REVERTED] PR [#287](https://github.com/3scale/apisonator/pull/287) and [#290](https://github.com/3scale/apisonator/pull/290) ([#306](https://github.com/3scale/apisonator/pull/306))
- Ruby 2.7, Redis 5.0.3 ([#309](https://github.com/3scale/apisonator/pull/309))
- Puma 4.3.9 ([#315](https://github.com/3scale/apisonator/pull/315))
- Async-pool 0.3.12 ([#324](https://github.com/3scale/apisonator/pull/324))
- Remove SaaS mode ([#325](https://github.com/3scale/apisonator/pull/325))

## 3.4.3 - 2021-06-23

### Fixed

- Fixed bug that causes Apisonator to stop pinging Porta to fetch events. This
bug triggers very rarely
([#292](https://github.com/3scale/apisonator/pull/292)).

## 3.4.2 - 2021-06-17

### Fixed

- Fixed exception raised when TTL = 0 in `UsagesChecked.mark_all_checked`
([#290](https://github.com/3scale/apisonator/pull/290)).

## 3.4.1 - 2021-06-16

### Changed

- Introduced performance optimizations around alerts detection
([#287](https://github.com/3scale/apisonator/pull/287)).

## 3.4.0 - 2021-06-14

### Added

- New extension that list the keys of an application
([#284](https://github.com/3scale/apisonator/pull/284)).

### Changed

- It is now possible to use OIDC in the auth and authrep endpoints
([#280](https://github.com/3scale/apisonator/pull/280)).
- Updated multi-json to 1.15.0
([#278](https://github.com/3scale/apisonator/pull/278)).

### Removed

- Deleted unused service attributes related with deleted end-users functionality
([#277](https://github.com/3scale/apisonator/pull/277)).

## 3.3.3 - 2021-03-09

### Changed

- Check if alerts can be raised before calculating utilization (perf
optimization) ([#275](https://github.com/3scale/apisonator/pull/275)).

### Removed

- Stop maintaining unused "current_max" key in Alerts
([#272](https://github.com/3scale/apisonator/pull/272)).

## 3.3.2 - 2021-02-23

### Fixed

- Fixed nil exception in `Aggregator.process`
([#269](https://github.com/3scale/apisonator/pull/269)).

### Changed

- Updated to Ruby 2.7 in Docker images
([#265](https://github.com/3scale/apisonator/pull/265)) and
([#266](https://github.com/3scale/apisonator/pull/266)).
- Updated pry to 0.14.0 and pry-doc to 1.1.0
([#267](https://github.com/3scale/apisonator/pull/267)).
- Updated Docker image to be based on RHEL UBI 8
([#268](https://github.com/3scale/apisonator/pull/268)).

### Removed

- Removed redundant prometheus config params
(`listener_prometheus_metrics.enabled` and `listener_prometheus_metrics.port`)
([#270](https://github.com/3scale/apisonator/pull/270)).

## 3.3.1.1 - 2021-02-12

### Changed

- Updated our Puma fork to v4.3.7
([#261](https://github.com/3scale/apisonator/pull/261)).

## 3.3.1 - 2021-02-11

### Fixed

- Usages with `#0` (set to 0) no longer generate unnecessary stats keys in Redis
([#258](https://github.com/3scale/apisonator/pull/258)).

## 3.3.0 - 2021-02-09

### Added

- Rake task to delete stats keys set to 0 in the DB left there because of [this
issue](https://github.com/3scale/apisonator/pull/247)
([#250](https://github.com/3scale/apisonator/pull/250)).

### Fixed

- Made the worker more reliable when configured in async mode. Now it handles
connection errors better
([#253](https://github.com/3scale/apisonator/pull/253)),
([#254](https://github.com/3scale/apisonator/pull/254)), and
([#255](https://github.com/3scale/apisonator/pull/255)).

### Changed

- Updated async-redis to v0.5.1
([#251](https://github.com/3scale/apisonator/pull/251)).

## 3.2.1 - 2021-01-22

### Fixed

- Reports of 0 hits no longer generate unnecessary stats keys in Redis
([#247](https://github.com/3scale/apisonator/pull/247)).

## 3.2.0 - 2021-01-19

### Added

- New endpoint in the internal API to get the provider key for a given (token,
service_id) pair ([#243](https://github.com/3scale/apisonator/pull/243)).

### Changed

- The config file used when running in a Docker image now parses "1" and "true"
(case-insensitive) as true
([#245](https://github.com/3scale/apisonator/pull/245)).

### Fixed

- Fixed some metrics of the internal API that were not being counted
correctly([#244](https://github.com/3scale/apisonator/pull/244)).


## 3.1.0 - 2020-10-14

### Added

- Prometheus metrics for the internal API
([#236](https://github.com/3scale/apisonator/pull/236)).
- Docs with a detailed explanation about how counter updates are performed
([#239](https://github.com/3scale/apisonator/pull/239)).

### Changed

- NotifyJobs are run only when the service ID is explicitly defined
([#238](https://github.com/3scale/apisonator/pull/238)).

### Fixed

- Fixed corner case that raised "TransactionTimestampNotWithinRange" in notify
jobs ([#235](https://github.com/3scale/apisonator/pull/235)).


## 3.0.1.1 - 2020-07-28

### Changed

- Updated json gem to v2.3.1
([#232](https://github.com/3scale/apisonator/pull/232)).

## 3.0.1 - 2020-07-14

### Fixed

- The Prometheus counter of "5xx" errors has been fixed
([#230](https://github.com/3scale/apisonator/pull/230)).

### Changed

- Gem updates: rack to v2.1.4
([#228](https://github.com/3scale/apisonator/pull/228)) and async-redis to
v0.5.0 ([#229](https://github.com/3scale/apisonator/pull/229)).


## 3.0.0 - 2020-06-19

### Removed

- Apisonator no longer supports the native oauth authorization mode. This is a
feature that was deprecated a long time ago
([#226](https://github.com/3scale/apisonator/pull/226)).


## 2.101.1 - 2020-06-05

### Fixed

- Fixed a bug introduced in the previous version that made apisonator return an
error when authorizing some requests with the `no_body` option enabled
([#224](https://github.com/3scale/apisonator/pull/224)).


## 2.101.0 - 2020-06-04

### Added

- Introduced the `CONFIG_REDIS_MAX_CONNS` and `CONFIG_QUEUES_MAX_CONNS` ENVs to
configure the max number of Redis connections when using the async mode
([#214](https://github.com/3scale/apisonator/pull/214)).

### Changed

- Perf optimization: loading the usage limits is now done more efficiently.
There is a noticeable improvement in requests with `no_body` enabled for
services with many metrics defined
([#221](https://github.com/3scale/apisonator/pull/221)).
- Updated activesupport to 5.2.4.3
([#217](https://github.com/3scale/apisonator/pull/217)).


## 2.100.2 - 2020-05-08

### Changed

- The Prometheus histogram buckets of the workers have been adjusted to be more
informative ([#208](https://github.com/3scale/apisonator/pull/208)).

### Removed

- The deprecated endpoints to create, delete, and list oauth tokens have been
disabled ([#212](https://github.com/3scale/apisonator/pull/212)).


## 2.100.1 - 2020-04-22

### Changed

- Now we are using our own redis-rb fork. It includes a fix that should reduce
the number of 5xx errors caused by Redis connection errors
([#205](https://github.com/3scale/apisonator/pull/205)).
- Updated hiredis to v0.6.3 ([#204](https://github.com/3scale/apisonator/pull/204)).

## 2.100.0 - 2020-04-21

### Added

- The behavior of the referrer filters validator is now configurable
([#190](https://github.com/3scale/apisonator/pull/190)).

### Fixed

- When running the listeners in async mode, Apisonator no longer returns
exception messages to the caller
([#186](https://github.com/3scale/apisonator/pull/186)).
- Fixed a small concurrency issue when running the workers in async mode. It
only affected to some job run times that appear in the logs
([#191](https://github.com/3scale/apisonator/pull/191)).

### Removed

- Deleted some unused rake tasks for uploading swagger specs
([#193](https://github.com/3scale/apisonator/pull/193)).

## 2.99.0 - 2020-03-31

### Added

- Support for specifying transaction timestamps as UNIX epoch timestamps
([#167](https://github.com/3scale/apisonator/pull/167))
- Prometheus metrics for the listener
([#174](https://github.com/3scale/apisonator/pull/174),
[#178](https://github.com/3scale/apisonator/pull/178))

### Changed

- Updated yabeda-prometheus to v0.5.0
([#171](https://github.com/3scale/apisonator/pull/171))
- Updated async-container to v0.16.4
([#179](https://github.com/3scale/apisonator/pull/179))
- Stopped propagating unused log attributes unnecessarily
([#180](https://github.com/3scale/apisonator/pull/180))
- No longer sets a default of 1 for `CONFIG_NOTIFICATION_BATCH` in the
Dockerfiles ([#183](https://github.com/3scale/apisonator/pull/183))

### Removed

- The "latest transactions" functionality has been removed. It was no longer
needed by Porta ([#169](https://github.com/3scale/apisonator/pull/169))

## 2.98.1.1 - 2020-03-05

### Changed

- Updated Nokogiri to v1.10.9 [#163](https://github.com/3scale/apisonator/pull/163)
- Updated Rake to v13.0.1 [#162](https://github.com/3scale/apisonator/pull/162)

## 2.98.1 - 2020-02-18

### Fixed

- No longer crashes when the address of a sentinel cannot be resolved. It tries
to connect to another sentinel in the list instead.
[#158](https://github.com/3scale/apisonator/pull/158)

## 2.98.0 - 2020-02-04

### Added

- Listeners can now be deployed in async mode using Falcon. Still experimental
[#150](https://github.com/3scale/apisonator/pull/150)
- Added the delete stats task to the `backend-cron` executable
[#156](https://github.com/3scale/apisonator/pull/156)

### Fixed

- Fixed a minor bug in the stats deletion feature. The task no longer crashes
with invalid keys [#154](https://github.com/3scale/apisonator/pull/154)
- `backend-cron` no longer crashes when `RESCHEDULE_JOBS_FREQ` is set
[#155](https://github.com/3scale/apisonator/pull/155)

## 2.97.0 - 2020-01-13

### Added

- New "flat_usage" extension, useful for caching. [#142](https://github.com/3scale/apisonator/pull/142)

### Changed

- New approach to delete the stats of a service [#143](https://github.com/3scale/apisonator/pull/143)
- Updated Rack to 2.0.8 [#144](https://github.com/3scale/apisonator/pull/144)

## 2.96.2 - 2019-10-17

### Added

- Async params can be configured using environment variables [#138](https://github.com/3scale/apisonator/pull/138)

### Fixed

- Rake tasks now work when using the async redis client [#137](https://github.com/3scale/apisonator/pull/137)

## 2.96.1 - 2019-10-10

### Changed

- Updated async-redis to v0.4.1 [#132](https://github.com/3scale/apisonator/pull/132)
- Updated rubyzip to v2.0.0 [#133](https://github.com/3scale/apisonator/pull/133)

## 2.96.0 - 2019-09-30

### Added

- Support for non-blocking Redis calls using the redis-async gem. The feature is
opt-in and can be enabled only in workers for now. The feature is enabled with
`CONFIG_REDIS_ASYNC=true` [#96](https://github.com/3scale/apisonator/pull/96)

## 2.95.0 - 2019-09-25

### Changed

- Dropped support for end-users [#128](https://github.com/3scale/apisonator/pull/128)

## 2.94.2 - 2019-09-10

### Changed

- Perf optimization: `Usage.usage` is more efficient now because it does not create unnecessary instance periods [#126](https://github.com/3scale/apisonator/pull/126)

## 2.94.1 - 2019-09-09

### Changed

- Perf optimization: `Metric.ascendants` and `Metric.descendants` are memoized now [#124](https://github.com/3scale/apisonator/pull/124)

## 2.94.0 - 2019-09-04

### Added

- Prometheus metrics for workers [#111](https://github.com/3scale/apisonator/pull/111)
- Support for metric hierarchies with more than 2 levels [#119](https://github.com/3scale/apisonator/pull/119), [#121](https://github.com/3scale/apisonator/pull/121), [#122](https://github.com/3scale/apisonator/pull/122)

### Changed

- Updated Nokogiri to v1.10.4 [#118](https://github.com/3scale/apisonator/pull/118)

## 2.93.0 - 2019-07-31

### Changed

- Dropped support for Ruby < 2.4 [#109](https://github.com/3scale/apisonator/pull/109)

## 2.92.0 - 2019-06-12

### Added

- Support for password-protected Redis sentinels [#101](https://github.com/3scale/apisonator/pull/101)
- New limit header with the max value for the limit [#103](https://github.com/3scale/apisonator/pull/103)
- CI tests now run on Ruby 2.5 and Ruby 2.6 too [#84](https://github.com/3scale/apisonator/pull/84), [#97](https://github.com/3scale/apisonator/pull/97)

### Changed

- Updated redis gem to v4.1.1 [#99](https://github.com/3scale/apisonator/pull/99)
- Performance optimizations in some time methods [#80](https://github.com/3scale/apisonator/pull/80), [#81](https://github.com/3scale/apisonator/pull/81)


## 2.91.1 - 2019-03-08

### Changed

- The endpoint of the internal API to delete stats of a service has been disabled because of performance issues. It will be re-enabled once those are solved. [#87](https://github.com/3scale/apisonator/pull/87)


## 2.91.0 - 2019-03-05

### Added

- New endpoint in the internal API to delete the stats of a service. [#72](https://github.com/3scale/apisonator/pull/72), [#73](https://github.com/3scale/apisonator/pull/73), [#74](https://github.com/3scale/apisonator/pull/74), [#78](https://github.com/3scale/apisonator/pull/78), [#82](https://github.com/3scale/apisonator/pull/82).

### Changed

- Rakefile now accepts a list of files as an argument in the "bench" target [#79](https://github.com/3scale/apisonator/pull/79)


## 2.90.0 - 2019-02-20

### Added

- New endpoint in the internal API to delete the users of a service. [#38](https://github.com/3scale/apisonator/pull/38)

### Changed

- Updated rack to v2.0.6. [#63](https://github.com/3scale/apisonator/pull/63)
- Updated Nokogiri to v1.9.1. [#70](https://github.com/3scale/apisonator/pull/70)

### Fixed

- Small fixes and improvements in the Makefiles and Dockerfiles used to build the docker images and the dev environment. [#61](https://github.com/3scale/apisonator/pull/61), [#64](https://github.com/3scale/apisonator/pull/64), [#67](https://github.com/3scale/apisonator/pull/67), [#68](https://github.com/3scale/apisonator/pull/68), [#69](https://github.com/3scale/apisonator/pull/69).


## 2.89.0 - 2018-10-23

### Added

- Tasks to check redis storage and queue storage connection. [#58](https://github.com/3scale/apisonator/pull/58)

### Security

- Updated rubyzip to version 1.2.2 due to [CVE-2018-1000544](https://access.redhat.com/security/cve/cve-2018-1000544). [#57](https://github.com/3scale/apisonator/pull/57)

## 2.88.1 - 2018-10-10

### Fixed

- The Limit Headers now show the correct information when the request is
  rate-limited. [#55](https://github.com/3scale/apisonator/pull/55)

## 2.88.0 - 2018-09-19

### Added

- Add documentation about utilization alerts. [#43](https://github.com/3scale/apisonator/pull/43)
- Set sentinel default port when no port is provided in Redis sentinel configuration. [#46](https://github.com/3scale/apisonator/pull/46)

### Changed

- When a Service is deleted delete all of its errors. [#44](https://github.com/3scale/apisonator/pull/44)
- When a Service is deleted all its transactions are deleted. [#45](https://github.com/3scale/apisonator/pull/45)
- Allow deletion of default service when it is the only existing one. [#51](https://github.com/3scale/apisonator/pull/51)

### Fixes

- Fix apisonator docker commands order in README. [#49](https://github.com/3scale/apisonator/pull/49)

## 2.87.2 - 2018-07-02

### Changed

- Allow defining Resque configuration without sentinels and defining non-localhost
  Resque configuration for development and test environments. [#41](https://github.com/3scale/apisonator/pull/41)

## 2.87.1 - 2018-06-27

### Fixes

- Fix existing Services prior the 2.87.0 release not being set as active by
  default [#39](https://github.com/3scale/apisonator/pull/39)

## 2.87.0 - 2018-06-21

### Added

- Services now can be active (default) or inactive. Calls on inactive services
  always fail, with authorizations being denied. ([#34](https://github.com/3scale/apisonator/issues/34))

### Changed

- Small cleaups and refactor of transactor code. ([#26](https://github.com/3scale/apisonator/pull/26))
- Allow multiple job schedulers to be executed in parallel with multiple Resque
  Redis servers. ([#29](https://github.com/3scale/apisonator/pull/29))
- Revamp README.md so that it is more oriented to usage and extract dev
  instructions to DEVELOPMENT.md. ([#33](https://github.com/3scale/apisonator/pull/33))

### Fixes

- Fix a race condition in a spec that tests a race condition. ([#32](https://github.com/3scale/apisonator/pull/32))

### Security

- Updated Sinatra to version 2.0.3 due to [CVE-2018-11627](https://nvd.nist.gov/vuln/detail/CVE-2018-11627). ([#30](https://github.com/3scale/apisonator/pull/30))
- Updated Nokogiri to version 1.8.3 due to multiple libxml2 CVEs including
  [CVE-2017-18258](https://nvd.nist.gov/vuln/detail/CVE-2017-18258).
  This library is only used in the test suite. ([#28](https://github.com/3scale/apisonator/pull/28), [#37](https://github.com/3scale/apisonator/pull/37))

## 2.86.0 - 2018-05-10

### Added

- The metrics used for reporting transactions and authorizations to the master
  account are now configurable under `master.metrics.transactions` and
  `master.metrics.transactions_authorize`. ([#15](https://github.com/3scale/apisonator/pull/15))
- There is now a set of rake targets for selectively run tests and specs by type
  (ie. integration, unit, etc) and by specific file. ([#11](https://github.com/3scale/apisonator/issues/11))
- The `make dev` command supports specifying an env variable `PORT` to expose
  the listener in that port on the local machine. ([#8](https://github.com/3scale/apisonator/pull/8))
- Minor miscellaneous improvements. ([#7](https://github.com/3scale/apisonator/pull/7), [#9](https://github.com/3scale/apisonator/pull/9), [#12](https://github.com/3scale/apisonator/issues/12), [#16](https://github.com/3scale/apisonator/pull/16), [#17](https://github.com/3scale/apisonator/pull/17), [#20](https://github.com/3scale/apisonator/pull/20), [#23](https://github.com/3scale/apisonator/pull/23), [#24](https://github.com/3scale/apisonator/pull/24))

### Changed

- Added extra measures to avoid creating applications through the internal API
  without mandatory attributes. ([#13](https://github.com/3scale/apisonator/pull/13))
- Some error conditions that produced empty or incorrect responses now behave
  like other errors and output XML bodies. ([#14](https://github.com/3scale/apisonator/pull/14), [#19](https://github.com/3scale/apisonator/pull/19))

### Fixed

- Running make in systems with a non-GNU version of `time` should stop failing
  because of using options supported only by GNU time. ([#5](https://github.com/3scale/apisonator/pull/5))
- Fixed a bug that made extra requests for stats with the inexistent `seconds`
  period. ([#21](https://github.com/3scale/apisonator/pull/21))
- Fixed a bug in dealing with the `notification_batch` configuration that made
  Apisonator enqueue NotifyJobs continuously when the setting was left
  unspecified. ([#22](https://github.com/3scale/apisonator/pull/22))

## 2.85.0 - 2018-03-19

### Added

- Support for specifying Redis Sentinel roles in the configuration file. This
  finished support for Redis HA through Sentinels. Use settings
  `config.redis.role` and `config.queues.role` to specify either `:master` or
  `:slave` _if_ you are using the Sentinel support.
- Set up the CI for the project in CircleCI with multiple Ruby versions.
- `make dev` will create a container for you to work in Apisonator sync'ing the
  contents with the repository.
- `make test` will optionally build the CI image from scratch.
