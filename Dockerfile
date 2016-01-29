FROM quay.io/3scale/docker:dev-backend-${RUBY_VERSION}
MAINTAINER Toni Reina <toni@3scale.net>

USER ruby
WORKDIR /tmp/backend/

ADD bin /tmp/backend/bin/
ADD Gemfile /tmp/backend/
ADD Gemfile.lock /tmp/backend/
ADD lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/
ADD 3scale_backend.gemspec /tmp/backend/

USER root
ADD docker/patches/0001-cubert-server.patch /tmp/
RUN ruby -e "begin; Gem::Specification.find_by_name('cubert-server', Gem::Requirement.create('= 0.0.2.pre.4')); rescue exit(1); end" || \
 patch -p1 -d $(ruby -e "puts Gem::Specification.find_by_name('cubert-server', Gem::Requirement.create('= 0.0.2')).gem_dir") < /tmp/0001-cubert-server.patch
RUN chown -R ruby: /tmp/backend/

USER ruby
RUN bundle install

USER root
RUN rm -rf /tmp/backend/

WORKDIR /home/ruby/backend/
ADD . /home/ruby/backend
RUN chown -R ruby: /home/ruby/backend

USER ruby
RUN bundle install

CMD ["script/ci"]
