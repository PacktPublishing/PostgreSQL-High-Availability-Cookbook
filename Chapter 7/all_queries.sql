-- Code to view status of repmgr:

SELECT standby_node, standby_name, replication_lag
  FROM repmgr_pgnet.repl_status;

-- Create a user for walctl replication purposes:

CREATE USER walctl
  WITH PASSWORD 'test' SUPERUSER REPLICATION;
