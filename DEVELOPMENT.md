# Apisonator

## Development environment set up

### Prerequisites

To learn how to run the project once the environment has been set up, refer to
the [Running](#running) section.

The first thing you will need is cloning the project:
> `$ git clone git@github.com:3scale/apisonator.git`

Next cd into the directory, `cd apisonator`.

### Ruby version management

In order to manage Ruby versions for local development, we recommend using [asdf](https://asdf-vm.com/guide/getting-started.html).

Once installed, use the provided `.tool-versions.sample` file to get the appropriate versions.

```
cp .tool-versions.sample .tool-versions
```

### Services

Apisonator requires a Redis server to run. By default, it will try to connect to:

```
redis://localhost:6379
```

A [podman-compose.yml](script/config/podman-compose.yml) file is provided in order
to make it easier to launch some preconfigured setups, like sentinels or twemproxy.

To launch a single redis instance listening in the default URL, just run:

```
podman-compose -f script/config/podman-compose.yml start redis-master
```

Keep in mind that the test suite can't be launched against a twemproxy.

### Configuring tests environment

The test suite will read the environment variables set in `/.env.test`.

You can set any [documented](docs/configuration.md) variable, for example, to make
the test suite point to another redis instance.

## Running tests

To execute all tests from within the development environment, run this command:

> `$ bundle exec script/test`

### Running tests (advanced)

You can execute the following command to run all tests:

> `$ bundle exec rake`

Or to run the tests in Asynchronous mode:

> `$ CONFIG_REDIS_ASYNC=true bundle exec rake`

You can also specify execution of individual tests or type of tests.

If the test is a Unit::Test type test (located in test directory) you can execute:
> `$ bundle exec rake test:[unit|integration|special] [TEST=<test-file]>`

If the test is a RSpec type test (located in spec directory) you can execute:
> `$ bundle exec rake spec:[unit|integration|acceptance|api|use_cases] SPEC=<test-file>`

Alternatively there is another syntax to execute a RSpec type test:
> `$ bundle exec rake spec:specific[<test-file>]`

where in this last case the [ ] characters must be literally placed.

Finally, you can also execute tests with rspec directly with:

> `$ RACK_ENV="test" bundle exec rspec --require=spec_helper <test-file>`

For more information on accepted commands for testing with Rake you can execute:

> `$ bundle exec rake -T`

### Testing API users from the outside

You can test users of Apisonator API services by starting its dependencies and
then apisonator itself:

> `$ bundle exec 3scale_backend start -p 3000`

This will launch the application and wait for requests. You could now ie. launch
[Pisoni](https://github.com/3scale/pisoni)'s testing against this Apisonator instance.

You can hit CTRL+C at any time to exit. If you wanted to pass extra parameters
for the launcher, such as daemonizing, you could run this:

> `$ bundle exec 3scale_backend start -p 3000 -d`

## Documentation

Make sure to read the corresponding Swagger-generated documentation,
located in [docs/active_docs/Service Management API.json](docs%2Factive_docs%2FService%20Management%20API.json)
for the external API.
You can also generate the documentation of the Internal API with Rake tasks.

## Contributing

This is our basic integration flow:

1. Fork the project.
2. Create a topic branch and add your changes there.
3. Create a Pull Request. To accept a PR, we require:
  1. The test suite should be green, both in the PR code and when merged.
  2. The core team or other contributors should review it.
  3. Someone in the core team should approve it.
4. Merge to master.

We keep stable branches receiving bug and security fixes for long term releases.

### Releasing a new version

Currently we need to follow this process:

1. Change the contents of version.rb with the new version.
2. Run `bundle install` with all Gemfiles to update all lockfiles.
3. Run `bundle exec rake license_finder:report:xml > licenses.xml`.
4. Modify CHANGELOG.md filling up data about notable changes along with
   associated issue or PR numbers where available.
5. Run `bundle exec rake release:changelog:link_prs` to link the issue or PR numbers in the
   CHANGELOG.md file and check the diff makes sense.
6. Review and commit "apisonator: release X.Y.Z".
7. Verify the tests pass and fix any issue that crops up. If at all possible,
   deploy the version as a pre-release in a staging environment for further
   testing and early detection of issues.
8. Post the PR on 3scale/apisonator.
9. When merged, generate the tag with `bundle exec rake release:tag` and push it. The tag
   should be a signed, annotated tag, usually with the format `vX.Y.Z`.

## Running

Apisonator has its own application runner for the listener service:

`bundle exec 3scale_backend help`

That will give you a help message so that you figure out how to invoke it. Some
advanced usage patterns are available, as well as support for multiple
application servers. The usual invocation would look something like:

> `$ bundle exec 3scale_backend start -p 3001`

That would start the listener service in port 3001. There are however additional
commands and flags that are worth knowing, so please take a look at the help
message. An interesting command would be this one:

> `$ bundle exec 3scale_backend -s puma -X "-w 3" start -p 3001`

That would be identical to the command above, except it would force the server
to be Puma with 3 workers. You can obtain more info about the server specific
options with:

> `$ bundle exec 3scale_backend -s puma help-server`

Additional information which is really important to how the application runs can
be found in the manifest:

> `$ bundle exec 3scale_backend manifest`

## Running from your IDE

Some IDEs like VSCode or RubyMine allow to add custom launchers for scripts. This is convenient to launch both Worker and Listener.

For that, you'll need to create the following configurations: 

### Worker

| Field                 | Value                                                   |
|-----------------------|---------------------------------------------------------|
| Name                  | `worker`                                                |
| Ruby script           | `/path/to/project/apisonator/bin/3scale_backend_worker` |
| Script arguments      | `--debug`                                               |
| Working directory     | `/path/to/project/apisonator`                           |
| Environment variables | `RACK_ENV=development`                                  |

In case you want to run the worker in async mode you can add `CONFIG_REDIS_ASYNC=true` to the environment variables here or directly add it to your `.env` file.

### Puma Listener (sync mode)

| Field                 | Value                                            |
|-----------------------|--------------------------------------------------|
| Name                  | `listener (puma)`                                |
| Ruby script           | `/path/to/project/apisonator/bin/3scale_backend` |
| Script arguments      | `-s puma -X start -p 3001`                       |
| Working directory     | `/path/to/project/apisonator`                    |
| Environment variables | `RACK_ENV=development`        |

### Falcon Listener (async mode)

| Field                 | Value                                                             |
|-----------------------|-------------------------------------------------------------------|
| Name                  | `listener (falcon)`                                               |
| Ruby script           | `/path/to/project/apisonator/bin/3scale_backend`                  |
| Script arguments      | `-s falcon start -p 3001`                                         |
| Working directory     | `/path/to/project/apisonator`                                     |
| Environment variables | `RACK_ENV=development;CONFIG_REDIS_ASYNC=true` |
