# Change Log

Notable changes to Apisonator will be tracked in this document.

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
