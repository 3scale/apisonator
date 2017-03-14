#!/bin/bash
# 3scale (operations@3scale.net)

# Optionally used to set up the Ruby/Bundler environment.
if [ -n "${ENV_SETUP}" ]; then
  eval "${ENV_SETUP}"
fi

set -u

if [[ -v LOG_FILE ]]; then
  tail -f $LOG_FILE &
fi

if [[ -v ERROR_LOG_FILE ]]; then
  tail -f $ERROR_LOG_FILE 1>&2 &
fi

exec bundle exec "$@"
