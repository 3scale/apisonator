# 3scale Backend image using the Red Hat 8 Universal Base Image (UBI) for
# minimal space release.
#
# Everything is set up in a single RUN command.
#
# This is based on and tracking the behavior of the more generic Dockerfile.
#
# Knobs you should know about:
#
# - RUBY_VERSION: Ruby version used.
# - BUILD_DEP_PKGS: Packages needed to build/install the project.
# - PUMA_WORKERS: (edit ENV) Default number of Puma workers to serve the app.
#

FROM registry.access.redhat.com/ubi8/ubi-minimal

ARG RUBY_VERSION="3.0"
ARG BUILD_DEPS="tar make file findutils git patch gcc automake autoconf libtool redhat-rpm-config openssl-devel ruby-devel"
ARG PUMA_WORKERS=1

# Set TZ to avoid glibc wasting time with unneeded syscalls
ENV TZ=:/etc/localtime \
    HOME=/home \
    # App-specific env
    RACK_ENV=production \
    CONFIG_LOG_PATH=/tmp/ \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

WORKDIR "${HOME}/app"

# Copy sources
COPY --chown=1001:1001 ./ "${HOME}/app/"

RUN echo -e "[ruby]\nname=ruby\nstream=${RUBY_VERSION}\nprofiles=\nstate=enabled\n" > /etc/dnf/modules.d/ruby.module \
 && microdnf update --nodocs \
 && microdnf install --nodocs ruby \
 && chown -R 1001:1001 "${HOME}" \
 && microdnf install --nodocs ${BUILD_DEPS} \
 && mkdir -p "${HOME}/.gem/bin" \
 && echo "gem: --bindir ~/.gem/bin" > "${HOME}/.gemrc" \
 && gem uninstall --executables bundler \
 && BUNDLED_WITH=$(cat Gemfile.lock | \
      grep -A 1 "^BUNDLED WITH$" | tail -n 1 | sed -e 's/\s//g') \
 && gem install -N bundler --version "${BUNDLED_WITH}" \
 && echo Using $(bundle --version) \
 && bundle config --local silence_root_warning 1 \
 && bundle config --local disable_shared_gems 1 \
 && bundle config --local without development:test \
 && bundle config --local gemfile Gemfile \
 && cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 644 /etc/3scale_backend.conf \
 && BACKEND_VERSION=$(gem build apisonator.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^[:space:]]*\)$/\1/p') \
 && gem unpack "apisonator-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/apisonator-${BACKEND_VERSION}" \
 && cp -a ${HOME}/app/.bundle "/opt/ruby/apisonator-${BACKEND_VERSION}/" \
 && bundle install --jobs $(grep -c processor /proc/cpuinfo) \
 && ln -s ${PWD} /opt/app \
 && cp ${HOME}/app/openshift/config/puma.rb ./config/ \
 && cp -n ${HOME}/app/openshift/backend-cron /usr/local/sbin/backend-cron \
 && cp -n ${HOME}/app/openshift/entrypoint.sh ./ \
 && rm -rf ${HOME}/app \
 && mkdir -p -m 0770 /var/run/3scale/ \
 && mkdir -p -m 0770 /var/log/backend/ \
 && touch /var/log/backend/3scale_backend{,_worker}.log \
 && chmod g+rw /var/log/backend/3scale_backend{,_worker}.log

EXPOSE 3000

USER 1001

WORKDIR /opt/app

ENTRYPOINT ["/bin/bash", "--", "/opt/app/entrypoint.sh"]
