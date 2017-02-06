#!/bin/bash

##
# Parameters are position-based and include:
#
# 1 - Host name of remote server to start.
# 2 - Path to data directory on remote server.

PATH=/bin:/usr/bin:/usr/local/bin

for x in {1..3}; do
  PATH=$PATH:/usr/lib/postgresql/9.$x/bin
done

if [ $# -lt 2 ]; then
    echo "Start a remote PostgreSQL server within pgpool."
    echo
    echo "Usage: $0 REMOTE_HOST REMOTE_PATH"
    echo
    exit 1
fi

remote_host=$1
remote_path=$2

options=$(cat postmaster.opts | sed 's/[^ ]* //;')
ssh postgres@$remote_host -T "pg_ctl -D $remote_path -o '$options' start" &>/dev/null &
