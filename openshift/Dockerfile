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

ARG BUNDLE_GEMFILE=Gemfile.on_prem
ARG BUNDLE_WITHOUT=development:test

COPY ${BUNDLE_GEMFILE}.lock ./
RUN source /tmp/scl_enable \
 && gem install -N bundler --version $(cat ${BUNDLE_GEMFILE}.lock | \
      grep -A 1 "^BUNDLED WITH$" | tail -n 1 | sed -e 's/\s//g') \
 && bundle config --local silence_root_warning 1 \
 && bundle config --local disable_shared_gems 1 \
 && bundle config --local without ${BUNDLE_WITHOUT} \
 && bundle config --local gemfile ${BUNDLE_GEMFILE}

COPY . ./

RUN source /tmp/scl_enable \
 && cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 644 /etc/3scale_backend.conf \
 && BACKEND_VERSION=$(gem build 3scale_backend.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^\s]*\)$/\1/p') \
 && gem unpack "3scale_backend-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/3scale_backend-${BACKEND_VERSION}" \
 && cp -a /tmp/backend/.bundle "/opt/ruby/3scale_backend-${BACKEND_VERSION}/" \
 && bundle install --deployment --jobs $(grep -c processor /proc/cpuinfo) \
 && ln -s ${PWD} /opt/app \
 && cp -n /tmp/backend/openshift/entrypoint.sh ./ \
 && cp -n /tmp/backend/openshift/backend-cron /usr/local/sbin/backend-cron \
 && cp /tmp/backend/openshift/config/puma.rb ./config/ \
 && cp -n /tmp/scl_enable ./ \
 && rm -rf /tmp/backend /tmp/scl_enable \
 && mkdir -p /var/run/3scale/ \
 && chgrp -R 0 /var/run/ \
 && chmod -R g+rw /var/run/ \
 && mkdir -p /var/log/backend/ \
 && touch /var/log/backend/3scale_backend.log \
 && touch /var/log/backend/3scale_backend_worker.log \
 && chmod -R g+rwx /var/log/backend/

EXPOSE 3000

USER 1001

WORKDIR /opt/app

ARG PUMA_WORKERS=1
ENV BASH_ENV=/opt/app/scl_enable \
    ENV=/opt/app/scl_enable \
    PROMPT_COMMAND=". /opt/app/scl_enable" \
    HOME=/tmp/ \
    PATH="${PATH}:/opt/app/bin" \
    # App-specific env
    CONFIG_SAAS=false \
    CONFIG_LOG_PATH=/tmp/ \
    CONFIG_NOTIFICATION_BATCH=1 \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

ENTRYPOINT ["/opt/app/entrypoint.sh"]
