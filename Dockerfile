FROM quay.io/3scale/docker:dev-backend-2.1.6
MAINTAINER Toni Reina <toni@3scale.net>

USER ruby
WORKDIR /tmp/backend/

ADD bin /tmp/backend/bin/
ADD Gemfile /tmp/backend/
ADD Gemfile.lock /tmp/backend/
ADD lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/
ADD 3scale_backend.gemspec /tmp/backend/

ADD docker/ssh /home/ruby/.ssh
USER root
RUN chown -R ruby:ruby /tmp/backend/ /home/ruby/.ssh

USER ruby
RUN bundle install

USER root
RUN rm -rf /tmp/backend/

WORKDIR /home/ruby/backend/
ADD . /home/ruby/backend
RUN chown -R ruby:ruby /home/ruby/backend

USER ruby
RUN bundle install

# this is needed for Vagrant to launch sshd
USER root

# and this is needed to switch to an unprivileged user for running the suite
CMD ["/bin/bash", "-c", "cd /home/ruby/backend && su ruby -c 'script/ci'"]
