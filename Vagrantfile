# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'berkshelf/vagrant'

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "precise32"
  config.berkshelf.enabled = true

  # config.vm.network :forwarded_port, guest: 3000, host: 8080

  config.vm.provision :chef_solo do |chef|
    chef.add_recipe 'apt'
    chef.add_recipe 'redisio::install'
    chef.add_recipe 'redisio::enable'
  end

  config.vm.provision :shell, :path => "cookbooks/bootstrap.sh"
end
