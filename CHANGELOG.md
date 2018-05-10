# Change Log

Notable changes to Apisonator will be tracked in this document.

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
