# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'berkshelf/vagrant'

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.provider "docker" do |v|
    v.cmd       = ["/usr/sbin/sshd", "-D"]
    v.build_dir = "."
    v.has_ssh = true
  end

  config.vm.network :forwarded_port, guest: 3000, host: 8081

  config.ssh.username = "root"
  config.ssh.private_key_path = "docker/ssh/docker_key"

  config.vm.synced_folder ".", "/vagrant"
end
