FROM quay.io/3scale/docker:dev-backend-${RUBY_VERSION}
MAINTAINER Toni Reina <toni@3scale.net>

WORKDIR /tmp/backend/

COPY bin /tmp/backend/bin/
COPY Gemfile Gemfile.lock Gemfile.base 3scale_backend.gemspec /tmp/backend/
COPY lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/

COPY docker/patches/0001-cubert-server.patch /tmp/
RUN ruby -e "begin; Gem::Specification.find_by_name('cubert-server', Gem::Requirement.create('= 0.0.2.pre.4')); rescue exit(1); end" || \
 patch -p1 -d $(ruby -e "puts Gem::Specification.find_by_name('cubert-server', Gem::Requirement.create('= 0.0.2')).gem_dir") < /tmp/0001-cubert-server.patch
RUN find $(ruby -e "puts Gem.dir") -type d -exec chmod go+rx {} \; \
 && find $(ruby -e "puts Gem.dir") -type f -exec chmod go+r {} \;
RUN chown -R ruby: /tmp/backend/

USER ruby
RUN bundle install

USER root
RUN rm -rf /tmp/backend/

WORKDIR /home/ruby/backend/
COPY . /home/ruby/backend
RUN chown -R ruby: /home/ruby/backend

USER ruby
RUN bundle install

CMD ["script/ci"]
