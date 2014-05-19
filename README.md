# 3scale API Management System Backend

This is 3scale's kick-ass ultra-scalable API management system backend.

## Development set up.

### With vagrant

1. Clone the project in your development workspace and cd to the directory.
2. Install VirtualBox
3. Install Vagrant (tested with v1.6.2 and v1.5.4).
4. Add vagrant plugins:
  1. omnibus plugin: `vagrant plugin install vagrant-omnibus`
  2. berkshelf plugin: `vagrant plugin install vagrant-berkshelf --plugin-version 2.0.1`
5. wait, joder: http://xkcd.com/303/
6. Add ubuntu precise32 box: `vagrant box add https://vagrantcloud.com/ubuntu/precise32`
7. Run vagrant up: `vagrant up`
  - If you get an error in this step similar to: `Failed to mount folders in Linux guest. This is usually because
the "vboxsf" file system is not available.` you need to execute some extra steps. If not, you can avoid them.
  1. Enter to the VM: `vagrant ssh`
  2. Symlink VboxGuestAdditions: `sudo ln -s /opt/VBoxGuestAdditions-4.3.10/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions`
  3. Exit ssh.
  4. Finish the provisioning: `vagrant reload --provision`
8. Now, you have the VM ready to hack. `vagrant ssh`
9. By default, your project is available in: /vagrant. `cd /vagrant`
10. Install bundle dependencies: `bundle install`.
11. Yay! That's all. You can for example, execute the tests: `bundle exec rake`.

## Deploy

1. Update the version.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. Git commit and push.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.
