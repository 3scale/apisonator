#!/bin/bash
# Set up a service with an application using user key, and add a limit on a metric for a low amount of hits, ie. 5.
# Then fill in the defaults below and call this script this way (note you can override any default when invoking it):
#
# For serial calls:   $ NUM_REQUESTS=8 ./limits.sh
# For parallel calls: $ PARALLEL=y NUM_REQUESTS=8 ./limits.sh
# For best results in parallel calls, set FILE=test such as:
# $ FILE=test PARALLEL=y NUM_REQUESTS=8 ./limits.sh
#
# You can also use SLEEP=0.1 to see effects adding a bit of time between requests (useful when in PARALLEL).

# Fill in with your defaults.
DEF_HOST="su1.3scale.net"
DEF_SVC_TOKEN="FILL_ME_IN"
DEF_SVC_ID="FILL_ME_IN"
DEF_USER_KEY="FILL_ME_IN"
DEF_METRIC="FILL_ME_IN"
DEF_NUM_REQUESTS="10"

HOST="${HOST:-${DEF_HOST}}"
SVC_TOKEN="${SVC_TOKEN:-${DEF_SVC_TOKEN}}"
SVC_ID="${SVC_ID:-${DEF_SVC_ID}}"
USER_KEY="${USER_KEY:-${DEF_USER_KEY}}"
METRIC="${METRIC:-${DEF_METRIC}}"
NUM_REQUESTS="${NUM_REQUESTS:-${DEF_NUM_REQUESTS}}"

REQUEST="https://${HOST}/transactions/authrep.xml?service_token=${SVC_TOKEN}&service_id=${SVC_ID}&user_key=${USER_KEY}&usage[${METRIC}]=1"

which curl 2> /dev/null >&2 || {
  echo >&2 "Please install curl"
  exit 1
}

which xmllint 2> /dev/null >&2 || {
  echo >&2 "Please install xmllint (usually provided by libxml2)"
  exit 1
}

do_req()
{
  curl -s "${REQUEST}" | xmllint --format -
}

calls()
{
  for r in $(seq ${NUM_REQUESTS}); do
    local outfile="${FILE:+${FILE}-${PARALLEL:+parallel-}${r}.xml}"
    local out="${outfile:-/dev/stdout}"

    if test "x${PARALLEL}" = "x"; then
      echo "Request ${r}..."
      do_req > "${out}"
    else
      do_req > "${out}" &
    fi

    test "x${SLEEP}" = "x" || sleep ${SLEEP}
  done

  echo "Done."
}

calls
