# 3scale Backend image using the Red Hat 9 Universal Base Image (UBI) as base
#
# This image is meant for flexibility building different configurations.
#
# Knobs you should know about:
#
# - RUBY_VERSION: Ruby version used.
# - BUILD_DEPS: Packages needed to build/install the project.
# - PUMA_WORKERS: Default number of Puma workers to serve the app.
#
# Profiles you should use:
#
# You can use variations on the values of arguments, but you usually want one
# of the following two use cases:
#
# - Development/Test: just use default values.
# - Release:
#   - PUMA_WORKERS: number of Puma worker processes - depends on intended usage,
#                   with number of cpus being a good heuristic.
#

FROM registry.access.redhat.com/ubi9/ubi-minimal

ARG RUBY_VERSION="3.3"
ARG BUILD_DEPS="tar make file findutils git patch gcc automake autoconf libtool redhat-rpm-config openssl-devel ruby-devel"

RUN microdnf module enable -y "ruby:${RUBY_VERSION}" \
 && microdnf install -y --nodocs ${BUILD_DEPS} \
 && microdnf clean all

# Copy sources
WORKDIR /opt/source
COPY ./ ./

# setup system
RUN cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 660 /etc/3scale_backend.conf \
 && cp -n openshift/backend-cron /usr/local/sbin/backend-cron \
 && mkdir -p -m 0770 /var/run/3scale/ \
 && mkdir -p -m 0770 /var/log/backend/ \
 && touch /var/log/backend/3scale_backend{,_worker}.log \
 && chmod g+rw /var/log/backend/3scale_backend{,_worker}.log \
 && chown -R 1001 . && chmod g+w /opt

# Install bundler globally (as root)
RUN BUNDLED_WITH=$(awk '/BUNDLED WITH/ { getline; print $1 }' Gemfile.lock) \
 && gem install --no-document bundler:$BUNDLED_WITH \
 && echo Using $(bundle --version), originally bundled with ${BUNDLED_WITH}

USER 1001

# Builds a clean source tree and deploys it with Bundler.
RUN BACKEND_VERSION=$(gem build apisonator.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^[:space:]]*\)$/\1/p') \
 && gem unpack "apisonator-${BACKEND_VERSION}.gem" --target=/tmp/ruby \
 && mv "/tmp/ruby/apisonator-${BACKEND_VERSION}" /opt/app \
 && rm -rf /tmp/ruby

WORKDIR /opt/app

# Install ruby dependencies and put things at the right places
RUN bundle config set --local build.nokogiri --use-system-libraries \
 && bundle config set --local without development:test \
 && bundle config set --local deployment true \
 && bundle install --jobs $(grep -c processor /proc/cpuinfo) \
 && cp /opt/source/openshift/config/puma.rb config/ \
 && cp -n /opt/source/openshift/entrypoint.sh ./ \
 && rm -rf /opt/source

EXPOSE 3000

ARG PUMA_WORKERS=1
ARG RACK_ENV=production

# Set TZ to avoid glibc wasting time with unneeded syscalls
ENV TZ=:/etc/localtime \
    # App-specific env
    RACK_ENV=${RACK_ENV} \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

ENTRYPOINT ["/opt/app/entrypoint.sh"]
