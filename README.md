# 3scale API Management System Backend

This is 3scale's kick-ass ultra-scalable API management system backend.

## Development environment set up

We recommend that you **DO NOT** install the software on your own machine but
instead use an isolated development environment.

To learn how to run the project once the environment has been set up, refer to
the "Running" section.

The first thing you will need is cloning the project:
> `$ git clone git@github.com:3scale/backend.git`

Next cd into the directory, `cd backend`.

### Isolated environment (supported)

#### Prerequisites

* Docker (tested with version 1.9.1)
* Vagrant (optional, tested with version 1.7.4)

Vagrant provides a couple of nice features on top of Docker for ease of
configuration, which is why we recommend it. However as we migrate more projects
and Docker gets better we might consider switching to Docker alone in the
future.

Follow the directions according to what you want to use.

#### With Vagrant

1. Build the container: `vagrant up`.
2. Enter the container: `vagrant ssh`.
3. Your project is available in `/vagrant`. Run `cd /vagrant`.

#### With Docker

1. Build the container: `make build`.
2. Enter the container: `make bash`.
3. Your project is available in `~/backend`.

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

### On local (unsupported)

This is **unsupported** and **strongly discouraged** because it is the source of a lot
of headaches and potential problems and introduces the need for us to document
dependencies and config files here that are very likely to be outdated and
incomplete. Don't even consider wasting anyone's time asking for help with this.

*You are basically on your own here*.

1. Install Redis v2.8.19 (or install it elsewhere).
2. Run `bundle install`.
3. Configure Redis in `~/.3scale_backend.conf` as:

```
ThreeScale::Backend.configure do |config|
  config.redis.proxy = 'localhost:6379'
end
```

### Testing API users / backend from outside

You can test users of backend API services by starting its dependencies and then backend itself:

> `$ script/test_external`

This will launch the application and wait for requests. You could now ie. launch
`3scale_core`'s testing against this backend instance.

You can hit CTRL+C at any time to exit. If you wanted to pass extra parameters
for the launcher, such as daemonizing, you could like this:

> `$ script/test_external -- -d`

## Running

Backend has its own application runner for the listener service:

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

1. Create a topic branch and add your changes there.
2. Create a Pull Request. To accept a PR, we require:
  1. Build in jenkins should be green.
  2. Team should review and approve it.
  3. Test the branch in preview environment. It should work correctly.
3. Merge to master.
4. Deploy to production.

Our preferred way to proceed is merge & deploy, only one feature/fix per deploy. This way has a lot of benefits for us.
But, there are no unbreakable rules, so if you have a good reason to deploy multiple things, go ahead.

### Deploy in preview

1. Update the version with ".pre" suffix.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. GIT commit is not needed. This version is something provisional and it can be done locally.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.
4. Probably you want to see how it works with traffic replayed form production.
5. Check the Grafana pretty graphs to make sure all keeps working.

### Deploy in production

1. Update the version.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. Git commit and push.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.
4. Check the Grafana pretty graphs to make sure all keeps working.

__Note:__ As you can see, here we have a process that we can automatize. This note is an invitation for bold developers.

