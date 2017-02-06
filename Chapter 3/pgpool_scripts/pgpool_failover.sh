#!/bin/bash

##
# This script will stop the primary PostgreSQL server so it can
# no longer replicate. Then it will promote the indicated replica
# node based on path. Parameters are position-based and include:
#
# 1 - Node ID that just disconnected from pgpool or failed.
# 2 - Node ID of the current primary node.
# 3 - Host name or IP address of the old primary.
# 4 - Host name or IP address of the new primary.
# 5 - Database Path for the old primary.
# 6 - Database Path for the new primary.
#
# Be sure to set up public SSH keys and authorized_keys files.

PATH=/bin:/usr/bin:/usr/local/bin

for x in {1..3}; do
  PATH=$PATH:/usr/lib/postgresql/9.$x/bin
done

if [ $# -lt 6 ]; then
    echo "Promote a PostgreSQL server within pgpool."
    echo
    echo -n "Usage: $0 FAIL_ID PRIMARY_ID"
    echo " OLD_HOST NEW_HOST OLD_PATH NEW_PATH"
    echo
    exit 1
fi

failed_node=$1
old_primary=$2

old_host=$3
new_host=$4
old_path=$5
new_path=$6

if [ "$old_primary" = "$failed_node" ]; then
    ssh postgres@$old_host -T "pg_ctl -D $old_path stop -m fast"
    sleep 10
    ssh postgres@$new_host -T "pg_ctl -D $new_path promote"
fi
