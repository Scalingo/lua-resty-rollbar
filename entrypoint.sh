#!/bin/bash

function wait_no_limit() {
  tail -F /dev/null &
  wait $!
}

echo "============="
echo "Container ready, run 'docker compose exec test bin/specs' to execute tests"
echo "============="

trap "exit 0" TERM INT

wait_no_limit
