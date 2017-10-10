# 3scale Backend CentOS image
#
# This image is meant for flexibility building different configurations.
#
# Knobs you should know about:
#
# - RUBY_SCL: Software Collections Library for the Ruby version used.
# - BUILD_DEP_PKGS: Packages needed to build/install the project.
# - CACHE_FRIENDLY: Improve caching when rebuilding at the cost of bigger size.
# - GEM_UPDATE: Update Rubygems to the latest version.
# - BUNDLE_VERSION_MATCH: Install the Bundler version used by the lockfile
#                         instead of using the SCL version.
# - BUNDLE_GEMFILE: Gemfile name to pin Bundler to.
# - BUNDLE_WITHOUT: List of Bundler groups to skip.
# - DELETE_UNUSED_GEMFILES: Deletes unused Gemfiles in the root directory.
# - CONFIG_SAAS: true for a SaaS image. false for an on-premises image.
# - PUMA_WORKERS: Default number of Puma workers to serve the app.
#
# Profiles you should use:
#
# You can use variations on the values of arguments, but you usually want one
# of the following two use cases:
#
# - Development/Test: just use default values.
# - Release:
#   - CACHE_FRIENDLY: false
#   - GEM_UPDATE: false
#   - BUNDLE_VERSION_MATCH: false
#   - BUNDLE_GEMFILE: Gemfile for SaaS, Gemfile.on_prem for on-premises.
#   - BUNDLE_WITHOUT: development:test
#   - DELETE_UNUSED_GEMFILES: true
#   - CONFIG_SAAS: true for SaaS, false for on-premises.
#   - PUMA_WORKERS: number of Puma worker processes - depends on intended usage,
#                   with number of cpus being a good heuristic.
#

FROM centos:7

ARG RUBY_SCL=rh-ruby23
ARG BUILD_DEP_PKGS="make gcc git"
# Turn off for release mode to produce smaller layers.
ARG CACHE_FRIENDLY=true

# Configure yum, install SCL, update, install Ruby and clean.
RUN sed -i /etc/yum.conf -e \
      '/^\(clean_requirements_on_remove\|history_record\|tsflags\|logfile\)=/d' -e \
      's/^\(\[main\]\b.*\)$/\1\nclean_requirements_on_remove=1\nhistory_record=0\ntsflags=nodocs\nlogfile=\/dev\/null\n/' \
      /etc/yum.conf \
 && yum install -y centos-release-scl \
 && yum -y update \
 && yum -y install ${RUBY_SCL} ${RUBY_SCL}-ruby-devel \
 && if test "${CACHE_FRIENDLY}x" = "truex"; then \
      yum -y install ${BUILD_DEP_PKGS} ; \
    fi \
 && yum -y autoremove \
 && yum -y clean all

WORKDIR /tmp/app

# Gem updating should be turned off for productisation
ARG GEM_UPDATE=true
# Bundler should be kept as-is for productisation
ARG BUNDLE_VERSION_MATCH=true
ARG BUNDLE_GEMFILE=Gemfile.on_prem
ARG BUNDLE_WITHOUT=development:test

# Install and/or update Rubygems and Bundler, and configure the latter.
COPY ${BUNDLE_GEMFILE}.lock ./
RUN source scl_source enable ${RUBY_SCL} \
 && if test "${GEM_UPDATE}x" = "truex"; then \
      gem update --system -N ; \
    fi \
 && gem env \
 && BUNDLED_WITH=$(cat ${BUNDLE_GEMFILE}.lock | \
      grep -A 1 "^BUNDLED WITH$" | tail -n 1 | sed -e 's/\s//g') \
 && if test "${BUNDLE_VERSION_MATCH}x" = "truex"; then \
      gem install -N bundler --version ${BUNDLED_WITH} ; \
    else \
      yum install -y ${RUBY_SCL}-rubygem-bundler \
        && yum -y autoremove && yum -y clean all ; \
    fi \
 && echo Using $(bundle --version), originally bundled with ${BUNDLED_WITH} \
 && bundle config --local silence_root_warning 1 \
 && bundle config --local disable_shared_gems 1 \
 && bundle config --local without ${BUNDLE_WITHOUT} \
 && bundle config --local gemfile ${BUNDLE_GEMFILE}

COPY . ./

ARG DELETE_UNUSED_GEMFILES=true
# Turn off for productisation
ARG CONFIG_SAAS=false

# Builds a clean source tree and deploys it with Bundler.
# Sets the right configuration and permissions.
RUN source scl_source enable ${RUBY_SCL} \
 && cp -n openshift/3scale_backend.conf /etc/ \
 && chmod 644 /etc/3scale_backend.conf \
 && BACKEND_VERSION=$(gem build 3scale_backend.gemspec | \
      sed -n -e 's/^\s*Version\:\s*\([^[:space:]]*\)$/\1/p') \
 && gem unpack "3scale_backend-${BACKEND_VERSION}.gem" --target=/opt/ruby \
 && cd "/opt/ruby/3scale_backend-${BACKEND_VERSION}" \
 && cp -a /tmp/app/.bundle "/opt/ruby/3scale_backend-${BACKEND_VERSION}/" \
 && if test "${DELETE_UNUSED_GEMFILES}x" = "truex"; then \
      echo "Deleting the following unused Gemfile files:"; \
      find . -maxdepth 1 -regex \./Gemfile"\(\..*\)?" \
      ! -regex \./$(sed -e 's/[^^]/[&]/g; s/\^/\\^/g' <<< ${BUNDLE_GEMFILE})"\(\.lock\)?" \
      ! -name Gemfile.base -print -delete; \
    fi \
 && if test "${CACHE_FRIENDLY}x" != "truex"; then \
      yum -y install ${BUILD_DEP_PKGS} ; \
    fi \
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
 && if test "${CONFIG_SAAS}x" != "truex"; then \
      cp /tmp/app/openshift/config/puma.rb ./config/ ; \
    fi \
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

ARG PUMA_WORKERS=1
ARG RACK_ENV=production

# Set TZ to avoid glibc wasting time with unneeded syscalls
ENV TZ=:/etc/localtime \
    HOME=/tmp/ \
    ENV_SETUP=". scl_source enable ${RUBY_SCL}" \
    # App-specific env
    RACK_ENV=${RACK_ENV} \
    CONFIG_SAAS=${CONFIG_SAAS} \
    CONFIG_LOG_PATH=/tmp/ \
    CONFIG_NOTIFICATION_BATCH=1 \
    CONFIG_WORKERS_LOG_FILE=/dev/stdout \
    PUMA_WORKERS=${PUMA_WORKERS}

ENTRYPOINT ["/bin/bash", "--", "/opt/app/entrypoint.sh"]
