FROM quay.io/3scale/apisonator-ci
MAINTAINER Alejandro Martinez Ruiz <amr@redhat.com>

ARG APP_HOME
RUN mkdir "${APP_HOME}"

WORKDIR "${APP_HOME}"

ARG DEV_TOOLS
RUN test "x${DEV_TOOLS}" = "x" || sudo yum install -y ${DEV_TOOLS}

CMD ["/bin/bash", "-c", "rbenv_update_env && bundle_install_rubies && script/test"]
