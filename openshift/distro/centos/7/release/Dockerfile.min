# 3scale Backend CentOS image for minimal space release.
#
# Everything is set up in a single RUN command.
#
# This is based on and tracking the behavior of the more generic Dockerfile.
#
# Knobs you should know about:
#
# - RUBY_SCL: Software Collections Library for the Ruby version used.
# - BUILD_DEP_PKGS: Packages needed to build/install the project.
# - PUMA_WORKERS: (edit ENV) Default number of Puma workers to serve the app.
#
FROM centos:7

ARG RUBY_SCL=rh-ruby23
ARG BUILD_DEP_PKGS="make gcc git"
ARG PUMA_WORKERS=1

# Set TZ to avoid glibc wasting time with unneeded syscalls
ENV TZ=:/etc/localtime \
    HOME=/tmp/ \
    ENV_SETUP=". scl_source enable ${RUBY_SCL}" \
    # App-specific env
    RACK_ENV=production \
    CONFIG_SAAS=false \
    CONFIG_LOG_PATH=/tmp/ \
    CONFIG_NOTIFICATION_BATCH=1 \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

WORKDIR /tmp/app
COPY . ./

# Configure yum, install SCL, update, install Ruby and clean.
RUN sed -i /etc/yum.conf -e \
      '/^\(clean_requirements_on_remove\|history_record\|tsflags\|logfile\)=/d' -e \
      's/^\(\[main\]\b.*\)$/\1\nclean_requirements_on_remove=1\nhistory_record=0\ntsflags=nodocs\nlogfile=\/dev\/null\n/' \
      /etc/yum.conf \
 && yum install -y centos-release-scl \
 && yum -y update \
 && yum -y install ${RUBY_SCL} ${RUBY_SCL}-ruby-devel ${RUBY_SCL}-rubygem-bundler \
 && yum -y autoremove \
 && yum -y clean all \
 && source scl_source enable ${RUBY_SCL} \
 && gem env \
 && echo Using $(bundle --version) \
 && bundle config --local silence_root_warning 1 \
 && bundle config --local disable_shared_gems 1 \
 && bundle config --local without development:test \
 && bundle config --local gemfile Gemfile.on_prem \
 && cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 644 /etc/3scale_backend.conf \
 && BACKEND_VERSION=$(gem build 3scale_backend.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^[:space:]]*\)$/\1/p') \
 && gem unpack "3scale_backend-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/3scale_backend-${BACKEND_VERSION}" \
 && cp -a /tmp/app/.bundle "/opt/ruby/3scale_backend-${BACKEND_VERSION}/" \
 && echo "Deleting the following unused Gemfile files:" \
 && find . -maxdepth 1 -regex \./Gemfile"\(\..*\)?" \
      ! -regex \./$(sed -e 's/[^^]/[&]/g; s/\^/\\^/g' <<< Gemfile.on_prem)"\(\.lock\)?" \
      ! -name Gemfile.base -print -delete \
 && yum -y install ${BUILD_DEP_PKGS} \
 && bundle install --deployment --jobs $(grep -c processor /proc/cpuinfo) \
# Bundler < 1.12.0 needs fixing for git gems with extensions (Puma)
 && if ruby -e "begin; require 'rubygems'; Gem::Specification.find_by_name('bundler').version < Gem::Version.new('1.12.0') && exit(0); rescue; end; exit(1)"; then \
      echo "[WARNING] Old Bundler requires fixing git gems with extensions (Puma)" ; \
      PUMA_DIR=$(bundle show puma) \
      && ln -s $(find "${PUMA_DIR}" -name puma_http11.so) "${PUMA_DIR}"/lib/puma ; \
    fi \
 && yum -y remove ${BUILD_DEP_PKGS} \
 && yum -y autoremove \
 && yum -y clean all \
 && ln -s ${PWD} /opt/app \
 && cp /tmp/app/openshift/config/puma.rb ./config/ \
 && cp -n /tmp/app/openshift/backend-cron /usr/local/sbin/backend-cron \
 && cp -n /tmp/app/openshift/entrypoint.sh ./ \
 && rm -rf /tmp/app \
 && mkdir -p -m 0770 /var/run/3scale/ \
 && mkdir -p -m 0770 /var/log/backend/ \
 && touch /var/log/backend/3scale_backend{,_worker}.log \
 && chmod g+rw /var/log/backend/3scale_backend{,_worker}.log

EXPOSE 3000

USER 1001

WORKDIR /opt/app

ENTRYPOINT ["/bin/bash", "--", "/opt/app/entrypoint.sh"]
