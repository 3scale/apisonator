FROM quay.io/3scale/ruby-base:xenial-2.2.4

ARG BUNDLE_GEMINABOX="geminabox_user:geminabox_password"
ARG CORE_VERSION

RUN gem install 3scale_core --version ${CORE_VERSION} --no-document --source "https://${BUNDLE_GEMINABOX}@host"

USER 1001
