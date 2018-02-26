# Apisonator

This is Red Hat 3scale API Management Platform's Backend.

This software is licensed under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).

See the LICENSE and NOTICE files that should have been provided along with this
software for details.

## Development environment set up

The development environment currently needs a private container image. We
recommend that for the time being you set up the project with a Ruby interpreter
in your development machine and one of the multiple Ruby version and gemsets
managers such as RVM or rbenv.

To learn how to run the project once the environment has been set up, refer to
the "Running" section.

The first thing you will need is cloning the project:
> `$ git clone git@github.com:3scale/apisonator.git`

Next cd into the directory, `cd apisonator`.

### Containerized environment

#### Prerequisites

* Docker (requires version 1.10.0 or later)

#### With Docker

This requires GNU Make and has a single step:

1. Run: `make dev`

This command will take care of downloading and building all dependencies. Once
that is done, the process will be way faster the next time.

The project's source code will be available in `~/apisonator` and sync'ed with
your local apisonator directory, so you can edit files in your preferred
environment and still be able to run whatever you need inside the Docker
container.

This Docker container is persistent, so your changes will be kept the next time
you enter it. If you want to use a temporary, throw-away container you'd just
run `make bash`, since it will autoremove the container on exit.

Getting rid of the persistent container is done with `make devclean`.

#### Maintain your dependencies up-to-date

Changes in code sometimes translate into changes in dependencies. If that is the
case, your container will lag behind in dependencies, and some things might just
start breaking. You might want to make a habit of making sure dependencies are
updated when you enter your container. Run this from the project directory:

> $ `bundle install`

#### Workflow

Your project directory within the container is sync'ed with your local clone of
the project so that changes in one reflect instantly in the other.

We recommend editing code and committing locally, and executing tests within the
container, since the container won't have your own tools and configurations.

### On local machine (unsupported)

This is **unsupported** and **strongly discouraged** because it is the source of a lot
of headaches and potential problems and introduces the need for us to document
dependencies and config files here that are very likely to be outdated and
incomplete. This is the current method available for people without access to
the private container image.

Bear in mind that we can only provide best effort support for this.

1. Install Redis v2.8.19 (or install it elsewhere).
2. Run `bundle install`.
3. Configure Redis in `~/.3scale_backend.conf` as:

```
ThreeScale::Backend.configure do |config|
  config.redis.proxy = 'localhost:6379'
end
```

### Testing API users from the outside

You can test users of Apisonator API services by starting its dependencies and
then apisonator itself:

> `$ script/test_external`

This will launch the application and wait for requests. You could now ie. launch
`3scale_core`'s testing against this backend instance.

You can hit CTRL+C at any time to exit. If you wanted to pass extra parameters
for the launcher, such as daemonizing, you could run this:

> `$ script/test_external -- -d`

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

## Documentation

Make sure to read the corresponding documentation in [ActiveDocs](https://support.3scale.net/reference/active-docs) for the external
API. You can also generate the documentation of the Internal API with Rake tasks.

## Integration flow

This is our basic integration flow:

1. Fork the project.
2. Create a topic branch and add your changes there.
3. Create a Pull Request. To accept a PR, we require:
  1. The test suite should be green, both in the PR code and when merged.
  2. The core team or other contributors should review it.
  3. Someone in the core team should approve it.
4. Merge to master.

We keep stable branches receiving bug and security fixes for long term releases.
