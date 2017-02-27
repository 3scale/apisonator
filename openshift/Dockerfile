FROM centos:7

RUN yum install -y centos-release-scl \
    && yum install -y rh-ruby23 rh-ruby23-ruby-devel

COPY openshift/contrib/scl_enable /tmp/

RUN yum -y update \
 && yum -y install make gcc git \
 && source /tmp/scl_enable \
 && gem update --system \
 && gem env

WORKDIR /tmp/backend

COPY Gemfile.on_prem.lock ./
RUN source /tmp/scl_enable \
 && gem install -N bundler --version $(cat Gemfile.on_prem.lock | \
      grep -A 1 "^BUNDLED WITH$" | tail -n 1 | sed -e 's/\s//g') \
 && bundle config --global silence_root_warning 1 \
 && bundle config --global disable_shared_gems 1

ARG BUNDLE_WITHOUT=development:test

COPY . ./

RUN source /tmp/scl_enable \
 && cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 644 /etc/3scale_backend.conf \
 && rm Gemfile Gemfile.lock \
 && mv Gemfile.on_prem Gemfile \
 && mv Gemfile.on_prem.lock Gemfile.lock \
 && BACKEND_VERSION=$(gem build 3scale_backend.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^\s]*\)$/\1/p') \
 && gem unpack "3scale_backend-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/3scale_backend-${BACKEND_VERSION}" \
 && bundle install --deployment --jobs $(grep -c processor /proc/cpuinfo) \
 && ln -s ${PWD} /opt/app \
 && cp -n /tmp/backend/openshift/entrypoint.sh ./ \
 && cp -n /tmp/backend/openshift/backend-cron /usr/local/sbin/backend-cron \
 && cp -n /tmp/scl_enable ./ \
 && rm -rf /tmp/backend /tmp/scl_enable \
 && mkdir -p /var/run/3scale/ \
 && chgrp -R 0 /var/run/ \
 && chmod -R g+rw /var/run/ \
 && mkdir -p /var/log/backend/ \
 && touch /var/log/backend/3scale_backend.log \
 && touch /var/log/backend/3scale_backend_worker.log \
 && chmod -R g+rwx /var/log/backend/

WORKDIR /opt/app

ENV PATH="${PATH}:/opt/app/bin"

EXPOSE 3000

USER 1001

# Our user's HOME (needed by Bundler)
ENV HOME=/tmp/

ENV BASH_ENV=/opt/app/scl_enable \
    ENV=/opt/app/scl_enable \
    PROMPT_COMMAND=". /opt/app/scl_enable"

ENV CONFIG_LOG_PATH=/tmp/ CONFIG_WORKERS_LOG_FILE=/dev/stdout CONFIG_NOTIFICATION_BATCH=1 PUMA_WORKERS=1 CONFIG_SAAS=false

ENTRYPOINT ["/opt/app/entrypoint.sh"]
