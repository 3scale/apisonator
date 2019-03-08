# Change Log

Notable changes to Apisonator will be tracked in this document.

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
