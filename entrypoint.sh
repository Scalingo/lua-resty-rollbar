#!/bin/bash

function wait_no_limit() {
  tail -F /dev/null &
  wait $!
}

# export PATH=$PATH:/usr/local/openresty/bin:/usr/local/openresty/luajit/bin

echo "============="
echo "Container ready, run 'docker-compose exec test busted specs' to execute tests"
echo "============="

trap "exit 0" TERM INT

wait_no_limit
