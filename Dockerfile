FROM quay.io/3scale/docker:dev-backend-${RUBY_VERSION}
MAINTAINER Toni Reina <toni@3scale.net>

WORKDIR /tmp/backend/

COPY bin /tmp/backend/bin/
COPY Gemfile Gemfile.lock Gemfile.base 3scale_backend.gemspec /tmp/backend/
COPY lib/3scale/backend/version.rb /tmp/backend/lib/3scale/backend/

RUN find $(ruby -e "puts Gem.dir") -type d -exec chmod go+rx {} \; \
 && find $(ruby -e "puts Gem.dir") -type f -exec chmod go+r {} \;
# uninstall rack 2.0.0+ if present
RUN gem uninstall -x rack -v '>= 2.0.0' || true
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
