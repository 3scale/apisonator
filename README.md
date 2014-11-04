# 3scale API Management System Backend

This is 3scale's kick-ass ultra-scalable API management system backend.

## Development set up.

### With vagrant

1. Clone the project in your development workspace and cd to the directory.
2. Install Vagrant (tested with v1.6.2 and v1.5.4).
3. Run vagrant up: `vagrant up`
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

### Deploy in production

1. Update the version.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. Git commit and push.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.

__Note:__ As you can see, here we have a process that we can automatize. This note is an invitation for bold developers. 
