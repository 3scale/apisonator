FROM centos:7

ARG BUNDLE_WITHOUT=development:test

WORKDIR /opt/app

RUN yum install -y centos-release-scl \
    && yum install -y rh-ruby23 rh-ruby23-ruby-devel

COPY openshift/contrib/scl_enable /opt/app/etc/
ENV BASH_ENV=/opt/app/etc/scl_enable \
    ENV=/opt/app/etc/scl_enable \
    PROMPT_COMMAND=". /opt/app/etc/scl_enable"

RUN yum -y update \
 && yum -y install make gcc git \
 && source /opt/app/etc/scl_enable \
 && gem update --system \
 && gem install -N bundler \
 && gem env \
 && bundle config --global silence_root_warning 1 \
 && bundle config --global disable_shared_gems 1

ADD . ./

RUN rm Gemfile Gemfile.lock \
 && mv Gemfile.on_prem Gemfile \
 && mv Gemfile.on_prem.lock Gemfile.lock

RUN source /opt/app/etc/scl_enable \
 && BACKEND_VERSION=$(gem build 3scale_backend.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^\s]*\)$/\1/p') \
 && test "${BACKEND_VERSION}" != "" \
 && gem unpack "3scale_backend-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/3scale_backend-${BACKEND_VERSION}" \
 && bundle install --deployment --jobs $(grep -c processor /proc/cpuinfo) \
 && cp -R /opt/app/etc ./ && rm -rf /opt/app \
 && ln -sf ${PWD} /opt/app \
 && mkdir -p /var/run/3scale/

RUN mkdir -p /var/run/3scale && chgrp -R 0 /var/run/ && chmod -R g+rw /var/run/

WORKDIR /opt/app

ADD openshift/3scale_backend.conf /etc/

RUN mkdir -p /var/log/backend/ \
  && touch /var/log/backend/3scale_backend.log \
  && touch /var/log/backend/3scale_backend_worker.log \
  && chmod -R g+rwx /var/log/backend/ \
  && chmod 644 /etc/3scale_backend.conf

ENV PATH="${PATH}:/opt/app/bin"

EXPOSE 3000

COPY openshift/entrypoint.sh ./

COPY openshift/backend-cron /usr/local/sbin/backend-cron

USER 1001

# Our user's HOME (needed by Bundler)
ENV HOME=/tmp/

ENV CONFIG_LOG_PATH=/tmp/ CONFIG_WORKERS_LOG_FILE=/dev/stdout CONFIG_NOTIFICATION_BATCH=1 PUMA_WORKERS=1 CONFIG_SAAS=false

ENTRYPOINT ["/opt/app/entrypoint.sh"]
