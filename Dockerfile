FROM quay.io/3scale/ruby:2.1
MAINTAINER Toni Reina <toni@3scale> # 2014-06-16

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 136221EE520DDFAF0A905689B9316A7BC7917B12 \
 && echo 'deb http://ppa.launchpad.net/chris-lea/redis-server/ubuntu precise main' > /etc/apt/sources.list.d/redis-server.list \
 && apt-get -y -q update \
 && apt-get -y -q install redis-server mongodb \
 && echo 'Europe/Madrid' > /etc/timezone \
 && dpkg-reconfigure --frontend noninteractive tzdata

WORKDIR /tmp/backend/

ADD Gemfile /tmp/backend/
ADD Gemfile.lock /tmp/backend/
ADD lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/
ADD 3scale_backend.gemspec /tmp/backend/

RUN bundle install --without development --jobs `grep -c processor /proc/cpuinfo`

WORKDIR /opt/backend/

ADD . /opt/backend

RUN bundle config --local without development

CMD script/ci
