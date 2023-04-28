# 3scale Backend image using the Red Hat 8 Universal Base Image (UBI) as base
#
# This image is meant for flexibility building different configurations.
#
# Knobs you should know about:
#
# - RUBY_VERSION: Ruby version used.
# - BUILD_DEPS: Packages needed to build/install the project.
# - BUNDLE_VERSION_MATCH: Install the Bundler version used by the lockfile
#                         instead of using the SCL version.
# - BUNDLE_GEMFILE: Gemfile name to pin Bundler to.
# - BUNDLE_WITHOUT: List of Bundler groups to skip.
# - PUMA_WORKERS: Default number of Puma workers to serve the app.
#
# Profiles you should use:
#
# You can use variations on the values of arguments, but you usually want one
# of the following two use cases:
#
# - Development/Test: just use default values.
# - Release:
#   - GEM_UPDATE: false
#   - BUNDLE_VERSION_MATCH: false
#   - BUNDLE_WITHOUT: development:test
#   - PUMA_WORKERS: number of Puma worker processes - depends on intended usage,
#                   with number of cpus being a good heuristic.
#

FROM registry.access.redhat.com/ubi8/ubi-minimal

ENV HOME=/home
WORKDIR "${HOME}/app"

ARG RUBY_VERSION="3.0"
ARG RUNTIME_DEPS="ruby"

RUN echo -e "[ruby]\nname=ruby\nstream=${RUBY_VERSION}\nprofiles=\nstate=enabled\n" > /etc/dnf/modules.d/ruby.module \
 && microdnf update --nodocs \
 && microdnf install --nodocs ${RUNTIME_DEPS} \
 && chown -R 1001:1001 "${HOME}"

ARG BUILD_DEPS="tar make file findutils git patch gcc automake autoconf libtool redhat-rpm-config openssl-devel ruby-devel"

RUN microdnf install --nodocs ${BUILD_DEPS}

# Bundler should be kept as-is for productisation
ARG BUNDLE_VERSION_MATCH=true
# If the above is false
ARG BUNDLE_VERSION="2.3.5"

ARG BUNDLE_GEMFILE=Gemfile
ARG BUNDLE_WITHOUT=development:test

COPY --chown=1001:1001 ${BUNDLE_GEMFILE}.lock "${HOME}/app/"

RUN mkdir -p "${HOME}/.gem/bin" \
 && echo "gem: --bindir ~/.gem/bin" > "${HOME}/.gemrc"

RUN gem uninstall --executables bundler \
 && BUNDLED_WITH=$(cat ${BUNDLE_GEMFILE}.lock | \
      grep -A 1 "^BUNDLED WITH$" | tail -n 1 | sed -e 's/\s//g') \
 && if test "${BUNDLE_VERSION_MATCH}x" = "truex"; then \
      gem install -N bundler --version "${BUNDLED_WITH}"; \
    else \
      gem install -N bundler --version "${BUNDLE_VERSION}"; \
    fi \
 && echo Using $(bundle --version), originally bundled with ${BUNDLED_WITH} \
 && bundle config --local silence_root_warning 1 \
 && bundle config --local disable_shared_gems 1 \
 && bundle config --local without ${BUNDLE_WITHOUT} \
 && bundle config --local gemfile ${BUNDLE_GEMFILE}

# Copy sources
COPY --chown=1001:1001 ./ "${HOME}/app/"

# Builds a clean source tree and deploys it with Bundler.
# Sets the right configuration and permissions.
RUN cp -n openshift/3scale_backend.conf /etc/ \
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

ARG PUMA_WORKERS=1
ARG RACK_ENV=production

# Set TZ to avoid glibc wasting time with unneeded syscalls
ENV TZ=:/etc/localtime \
    # App-specific env
    RACK_ENV=${RACK_ENV} \
    CONFIG_LOG_PATH=/tmp/ \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

ENTRYPOINT ["/bin/bash", "--", "/opt/app/entrypoint.sh"]
