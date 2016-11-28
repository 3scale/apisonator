FROM centos:7

ARG BUNDLE_GEMINABOX="geminabox_user:geminabox_password"
ARG BUNDLE_WITHOUT=development:test

WORKDIR /opt/app

RUN yum install -y centos-release-scl \
    && yum install -y rh-ruby23 rh-ruby23-ruby-devel

COPY openshift/contrib/scl_enable /opt/app/etc/
ENV BASH_ENV=/opt/app/etc/scl_enable \
    ENV=/opt/app/etc/scl_enable \
    PROMPT_COMMAND=". /opt/app/etc/scl_enable"

RUN yum -y update \
 && yum -y groupinstall 'Development Tools' \
 && yum -y install postgresql-devel postgresql-libs \
 && source /opt/app/etc/scl_enable \
 && gem install bundle \
 && gem env \
 && bundle config --global silence_root_warning 1

ADD . ./

RUN source /opt/app/etc/scl_enable \
 && gem build 3scale_backend.gemspec \
 && gem unpack *.gem --target=/opt/ruby \
 && cd /opt/ruby/3scale_backend-$(cat Gemfile.lock | grep '3scale_backend (' | cut -f2 -d'(' | cut -f1 -d')') \
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
  && chmod -R g+wrx /var/log/backend/

EXPOSE 3000

COPY openshift/entrypoint.sh ./

COPY openshift/backend-cron /usr/local/sbin/backend-cron

USER 1001

ENV CONFIG_LOG_PATH=/tmp/ CONFIG_WORKERS_LOG_FILE=/dev/stdout CONFIG_NOTIFICATION_BATCH=1 CONFIG_STATS_BUCKET_SIZE=1 CONFIG_CAN_CREATE_EVENT_BUCKETS=true CONFIG_REDSHIFT_PORT=nil PUMA_WORKERS=1

ENTRYPOINT ["/opt/app/entrypoint.sh"]
