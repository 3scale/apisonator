FROM quay.io/3scale/docker:dev-2.1.6
MAINTAINER Toni Reina <toni@3scale> # 2014-06-16

RUN wget -qO- https://github.com/antirez/redis/archive/2.8.19.tar.gz | \
 tar xz && cd redis-2.8.19 && make && make install

RUN wget -qO- https://codeload.github.com/twitter/twemproxy/tar.gz/v0.3.0 | \
 tar xz && cd twemproxy-0.3.0 && autoreconf -fvi \
 && ./configure --prefix=/opt/twemproxy && make && make install

# influxdb requires for our user group write privileges in its shared dir
RUN wget http://s3.amazonaws.com/influxdb/influxdb_0.8.5_amd64.deb && \
 dpkg -i influxdb_0.8.5_amd64.deb && rm -f influxdb_0.8.5_amd64.deb && \
 usermod -a -G influxdb ruby && chmod -R g+w /opt/influxdb/shared

RUN gem install cubert-server --version=0.0.2.pre.4 --no-ri --no-rdoc

WORKDIR /opt/backend/
ADD . /opt/backend

ADD docker/ssh /home/ruby/.ssh
RUN chown -R ruby:ruby /opt/backend/ /home/ruby/.ssh

USER ruby
RUN bundle install

USER root
RUN ln -s /home/ruby/.bundle /root/.bundle && bundle install

CMD script/ci
