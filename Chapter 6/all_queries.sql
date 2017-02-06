-- Query to create rep_user user:

CREATE USER rep_user WITH REPLICATION;

-- Change the rep_user user's password:

ALTER USER rep_user WITH PASSWORD 'newpass';

-- Confirm streaming replication is started:

SELECT client_addr, usename, state
  FROM pg_stat_replication;

-- Similar to above, but with sync_state and application_name.

SELECT client_addr, state, sync_state, application_name
  FROM pg_stat_replication;

-- Get similar information from the replica node.

SELECT status, latest_end_lsn, latest_end_time, slot_name
  FROM pg_stat_wal_receiver;

-- Create a replication slot.

SELECT * FROM pg_create_physical_replication_slot('pg2_slot');

-- Drop a replication slot.

SELECT pg_drop_replication_slot('pg2_slot');
  
-- Test synchronous replication

CREATE TABLE foo ( bar INT );

-- Use this to temporarily disable synchronous replication.

SET synchronous_commit TO false;

-- Get a list of pgbench tables on subscription system.

SELECT schemaname, tablename
  FROM pg_tables
 WHERE tablename LIKE 'pgbench%';

-- Confirm replication of pgbench_accounts on subscriber:

SELECT count(1)
  FROM pgbench_accounts;

-- Install pglogical

CREATE EXTENSION pglogical;

-- Register a node into pglogical.

SELECT pglogical.create_node(
    node_name := 'node_name',
    dsn := 'host=host-addr dbname=postgres user=rep_user'
);

-- Create a pglogical replication set for inserts/updates only.

SELECT pglogical.create_replication_set(set_name := 'rep_set',
    replicate_insert := TRUE, replicate_update := TRUE,
    replicate_delete := FALSE, replicate_truncate := FALSE
);

-- Register a table into an existing replication set.

SELECT pglogical.replication_set_add_table(
    'rep_set', 'table_name'
);

-- Subscribe to a replication set from a subscriber node.

SELECT pglogical.create_subscription(
    subscription_name := 'sub_name',
    replication_sets := ARRAY['rep_set'],
    synchronize_data := TRUE,
    provider_dsn := 'host=origin_host dbname=postgres user=rep_user'
);

-- Check health of replication set from subscriber node.

SELECT subscription_name, status, provider_node,
       replication_sets
  FROM pglogical.show_subscription_status('pgbench');

