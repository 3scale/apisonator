# Apisonator

## Development environment set up

### Prerequisites

* Docker (requires version 1.10.0 or later)

To learn how to run the project once the environment has been set up, refer to
the [Running](#running) section.

The first thing you will need is cloning the project:
> `$ git clone git@github.com:3scale/apisonator.git`

Next cd into the directory, `cd apisonator`.

### Containerized environment

#### With Docker

This requires GNU Make and has a single step:

1. Run: `make dev`

This command will take care of downloading and building all dependencies. Once
that is done, the process will be way faster the next time.

The project's source code will be available in `~/apisonator` and sync'ed with
your local apisonator directory, so you can edit files in your preferred
environment and still be able to run whatever you need inside the Docker
container.

The listener service port (3000 by default) is automatically forwarded to the
host machine. The `make dev` command can be executed with the
environment variable `PORT` set to a different desired listener port value to
forward on the host machine.

This Docker container is persistent, so your changes will be kept the next time
you enter it.

Getting rid of the persistent container is done with `make dev-clean`, whereas
removing its image is done using `make dev-clean-image`.

Alternatively you can start a container with the service running with
`make dev-service`. This rule is intended for when you want to test
the service endpoint.

#### Maintain your dependencies up-to-date

Changes in code sometimes translate into changes in dependencies. If that is the
case, your container will lag behind in dependencies, and some things might just
start breaking. You might want to make a habit of making sure dependencies are
updated when you enter your container. Run this from the project directory:

> $ `bundle install`

The container image has additional tools to handle these dependencies for
multiple Ruby versions. Check out the `scripts` directory if you are curious.

#### Workflow

Your project directory within the container is sync'ed with your local clone of
the project so that changes in one reflect instantly in the other.

We recommend editing code and committing locally, and executing tests within the
container, since the container won't have your own tools and configurations.

## Running tests

You can either run them manually in the container-based development environment
or have a container launched just for running the tests. For the latter you just
need to run `make test`, and you can configure any additional environment
variables for the test scripts like so:

> `$ make DOCKER_OPTS="-e TEST_ALL_RUBIES=1" test`

Another alternative to execute all tests from within the development environment
where you should not need to manually start/stop the services before is to execute
them from inside the development environment via this script:

> `$ script/test`

### Running tests (advanced)

In order to run the tests manually in the container-based development, the services
needed to run them correctly must be started before with:

> `$ script/services start`

Then you can execute the following commands to execute all tests:

> `$ bundle exec rake`

In case you need it/want it, it is possible to manually stop the services by executing:
> `$ script/services stop`

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

> `$ script/test_external`

This will launch the application and wait for requests. You could now ie. launch
[Pisoni](https://github.com/3scale/pisoni)'s testing against this Apisonator instance.

You can hit CTRL+C at any time to exit. If you wanted to pass extra parameters
for the launcher, such as daemonizing, you could run this:

> `$ script/test_external -- -d`

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
3. Run `rake license_finder:report:xml > licenses.xml`.
4. (maybe) If you will generate a new CI image with `make ci-build`, change the
   configuration of `.circleci/config.yml` to point to the future image.
5. Modify CHANGELOG.md filling up data about notable changes along with
   associated issue or PR numbers where available.
6. Run task release:changelog:link_prs to link the issue or PR numbers in the
   CHANGELOG.md file and check the diff makes sense.
7. Review and commit "apisonator: release X.Y.Z".
8. Verify the tests pass and fix any issue that crops up. If at all possible,
   deploy the version as a pre-release in a staging environment for further
   testing and early detection of issues.
9. If you did step 4, build the new CI image, rebuild the dev image based on it,
   verify both work and tests pass using both, and push the CI image to quay.io.
10. Post the PR on 3scale/apisonator.
11. When merged, generate the tag with `rake release:tag` and push it. The tag
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
