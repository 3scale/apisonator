FROM quay.io/3scale/ruby:2.1
MAINTAINER Toni Reina <toni@3scale> # 2014-06-16

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 136221EE520DDFAF0A905689B9316A7BC7917B12 \
 && echo 'deb http://ppa.launchpad.net/chris-lea/redis-server/ubuntu precise main' > /etc/apt/sources.list.d/redis-server.list \
 && apt-get -y -q update \
 && apt-get -y -q install redis-server=2:2.8.19-1chl1~precise1 wget autoconf libtool autopoint openssh-server \
 && mkdir /var/run/sshd \
 && echo 'Europe/Madrid' > /etc/timezone \
 && dpkg-reconfigure --frontend noninteractive tzdata

RUN wget https://codeload.github.com/twitter/twemproxy/tar.gz/v0.3.0 \
 && tar xvzf v0.3.0 && cd twemproxy-0.3.0 && autoreconf -fvi \
 && ./configure --prefix=/opt/twemproxy && make && make install

RUN wget http://s3.amazonaws.com/influxdb/influxdb_0.8.5_amd64.deb \
 && dpkg -i influxdb_0.8.5_amd64.deb

RUN gem install cubert-server --version=0.0.2.pre.4 --no-ri --no-rdoc

WORKDIR /tmp/backend/

ADD Gemfile /tmp/backend/
ADD Gemfile.lock /tmp/backend/
ADD lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/
ADD 3scale_backend.gemspec /tmp/backend/

RUN bundle install --without development --jobs `grep -c processor /proc/cpuinfo`

WORKDIR /opt/backend/
ADD . /opt/backend
RUN bundle config --local without development

ADD docker/ssh /root/.ssh

CMD script/ci
