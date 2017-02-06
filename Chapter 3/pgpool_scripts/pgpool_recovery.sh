#!/bin/bash

##
# This script erase an existing replica and re-base it based on
# the current primary node. Parameters are position-based and include:
#
# 1 - Path to primary database directory.
# 2 - Host name of new node.
# 3 - Path to replica database directory
#
# Be sure to set up public SSH keys and authorized_keys files.

PATH=/bin:/usr/bin:/usr/local/bin

for x in {1..3}; do
  PATH=$PATH:/usr/lib/postgresql/9.$x/bin
done

if [ $# -lt 3 ]; then
    echo "Create a replica PostgreSQL from the primary within pgpool."
    echo
    echo "Usage: $0 PRIMARY_PATH HOST_NAME COPY_PATH"
    echo
    exit 1
fi

primary_host=$(hostname -i)
replica_host=$2
replica_path=$3

ssh_copy="ssh postgres@$replica_host -T"

$ssh_copy rm -Rf $replica_path
$ssh_copy "pg_basebackup -U postgres -h $primary_host -x -D $replica_path"
$ssh_copy "echo standby_mode = \'on\' > $replica_path/recovery.conf"
$ssh_copy "echo primary_conninfo = \'host=$primary_host user=postgres\' >> $replica_path/recovery.conf"
