#!/usr/bin/env bash

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
apt-get -y install ruby2.1 ruby2.1-dev
ruby-switch --set ruby2.1

# influxdb

apt-get install -y mongodb-10gen
service mongodb stop
wget http://s3.amazonaws.com/influxdb/influxdb_latest_i386.deb
dpkg -i influxdb_latest_i386.deb
chown -R vagrant:vagrant /opt/influxdb

# Dependencies
apt-get install -y libxslt-dev libxml2-dev
apt-get install -y autoconf libtool autopoint
wget https://codeload.github.com/twitter/twemproxy/tar.gz/v0.3.0 && tar xvzf v0.3.0 && cd twemproxy-0.3.0 && autoreconf -fvi && ./configure --prefix=/opt/twemproxy && make && make install

# Application setup
gem install bundler rake

su - vagrant -c "echo export LC_ALL=en_US.UTF8 >> ~/.bashrc"
