#!/bin/bash
# 3scale (operations@3scale.net)
set -u

if [[ -v LOG_FILE ]]; then
  tail -f $LOG_FILE &
fi

if [[ -v ERROR_LOG_FILE ]]; then
  tail -f $ERROR_LOG_FILE 1>&2 &
fi

exec bundle exec "$@"
