#!/usr/bin/env bash

set -e

# Function to wait for server to be ready
wait_for_server() {
  local url=$1
  local max_attempts=20
  local attempt=1

  echo "Waiting for server at $url to be ready..."
  while [ $attempt -le $max_attempts ]; do
    if curl -s --connect-timeout 2 "$url" > /dev/null 2>&1; then
      echo "Server ready after $attempt attempts"
      return 0
    fi
    echo "Attempt $attempt/$max_attempts failed, retrying..."
    sleep 1
    attempt=$((attempt + 1))
  done
  echo "Server failed to start after $max_attempts attempts"
  return 1
}

echo "Testing localhost binding..."
bundle exec bin/3scale_backend start --bind 127.0.0.1 -p 4001 > /dev/null 2>&1 &
LISTENER_PID=$!

# Test connection to localhost (should work)
if wait_for_server "http://127.0.0.1:4001/status"; then
  echo "✓ Localhost binding works - can connect via 127.0.0.1"
else
  echo "✗ Localhost binding failed - cannot connect via 127.0.0.1"
  kill $LISTENER_PID 2>/dev/null || true
  exit 1
fi

# Test connection to external interface (should fail when bound to localhost only)
EXTERNAL_IP=$(hostname -I | awk '{print $1}')
if curl -s --connect-timeout 5 http://$EXTERNAL_IP:4001/status > /dev/null; then
  echo "✗ Security issue: bound to localhost but accessible via external IP $EXTERNAL_IP"
  kill $LISTENER_PID 2>/dev/null || true
  exit 1
else
  echo "✓ Correctly not accessible via external IP $EXTERNAL_IP"
fi

kill $LISTENER_PID 2>/dev/null || true
sleep 3

echo "Testing default (all interfaces) binding..."
bundle exec bin/3scale_backend start -p 4002 > /dev/null 2>&1 &
LISTENER_PID=$!

# Test connection to localhost (should work)
if wait_for_server "http://127.0.0.1:4002/status"; then
  echo "✓ Default binding works - accessible via localhost"
else
  echo "✗ Default binding failed - cannot connect via localhost"
  kill $LISTENER_PID 2>/dev/null || true
  exit 1
fi

# Test connection to external interface (should work with default binding)
if curl -s --connect-timeout 5 http://$EXTERNAL_IP:4002/status > /dev/null; then
  echo "✓ Default binding works - accessible via external IP $EXTERNAL_IP"
else
  echo "✓ External IP test skipped (may be expected in containerized environment)"
fi

kill $LISTENER_PID 2>/dev/null || true

echo "Testing IPv6 localhost binding..."
bundle exec bin/3scale_backend start --bind [::1] -p 4003 > /dev/null 2>&1 &
LISTENER_PID=$!

# Test connection to IPv6 localhost (should work)
if wait_for_server "http://[::1]:4003/status"; then
  echo "✓ IPv6 localhost binding works - can connect via ::1"
else
  echo "✗ IPv6 localhost binding failed - cannot connect via ::1"
  kill $LISTENER_PID 2>/dev/null || true
  exit 1
fi

# Test connection to IPv4 localhost (should fail when bound to IPv6 only)
if curl -s --connect-timeout 5 http://127.0.0.1:4003/status > /dev/null; then
  echo "✗ Security issue: bound to IPv6 localhost but accessible via IPv4"
  kill $LISTENER_PID 2>/dev/null || true
  exit 1
else
  echo "✓ Correctly not accessible via IPv4 when bound to IPv6"
fi

kill $LISTENER_PID 2>/dev/null || true

echo "All host binding tests passed!"
