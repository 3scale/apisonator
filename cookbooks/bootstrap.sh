#!/usr/bin/env bash
export $LC_ALL=en_US.UTF8

# Extra repositories
apt-get install -y python-software-properties
apt-add-repository ppa:brightbox/ruby-ng
apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee -a /etc/apt/sources.list.d/10gen.list
apt-get update

# Basic config
echo "StrictHostKeyChecking no" > /home/vagrant/.ssh/config
echo "Europe/Madrid" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Basic tools
apt-get install -y git

# Ruby 1.9.3
apt-get -y install ruby rubygems ruby-switch
apt-get -y install ruby1.9.3
ruby-switch --set ruby1.9.1

# Dependencies
apt-get install -y libxslt-dev libxml2-dev
apt-get install -y mongodb-10gen

# Application setup
gem install bundler rake
