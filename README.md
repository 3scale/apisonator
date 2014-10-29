# 3scale API Management System Backend

This is 3scale's kick-ass ultra-scalable API management system backend.

## Development set up.

### With vagrant

1. Clone the project in your development workspace and cd to the directory.
2. Install Vagrant (tested with v1.6.2 and v1.5.4).
3. Run vagrant up: `vagrant up --provider=docker`
4. Now, you have a container ready to hack. `vagrant ssh`
5. By default, your project is available in: /vagrant. `cd /vagrant`
6. Yay! That's all. You can for example, execute the tests: `script/test`.

We recommend developing locally and execute tests in container.

### Testing API users / backend from outside

You can test users of backend API services by starting its dependencies and then backend itself:
```
$ script/services start
$ bundle exec bin/3scale_backend -p 3000 -d start
```
You could now ie. launch core testing against this backend instance.

Using stop in reverse order applies to stop testing:
```
$ bundle exec bin/3scale_backend stop
$ script/services stop
```

Alternatively you can do this without daemonizing backend using a single command:
```
$ script/test_external
```
Or you can perform a finer-grained process by invoking smaller steps:
```
$ . script/lib/functions
$ start_redis
$ start_twemproxy
...
```

## Deploy

1. Update the version.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. Git commit and push.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.
