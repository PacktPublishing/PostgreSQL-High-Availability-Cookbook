-- Query to check database activity:

SELECT * FROM (
SELECT d.datname AS database_name,
       d.xact_commit + d.xact_rollback AS transactions,
       d.tup_inserted + d.tup_updated + d.tup_deleted AS writes,
       sum(s.calls) AS queries
  FROM pg_stat_database d
  LEFT JOIN pg_stat_statements s ON (s.dbid = d.datid)
 WHERE d.datname NOT IN ('template0', 'template1', 'postgres')
 GROUP BY 1, 2, 3
) db
 WHERE db.transactions > 10000000
    OR db.writes > 100000000
    OR db.queries > 100000000;

-- View to find largest/most active tables

CREATE OR REPLACE VIEW v_shard_candidates AS
SELECT c.oid::regclass::text AS table_name,
       c.reltuples AS num_rows,
       pg_total_relation_size(c.oid) AS total_size,
       pg_total_relation_size(c.oid) / 1048576 AS size_mb,
       t.n_tup_ins + t.n_tup_upd + t.n_tup_del AS writes
  FROM pg_class c
  JOIN pg_namespace n ON (n.oid = c.relnamespace)
  JOIN pg_stat_user_tables t ON (t.relid = c.oid)
 WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
   AND c.relkind = 'r'
   AND (c.reltuples > 10000000 OR
        t.n_tup_ins + t.n_tup_upd + t.n_tup_del > 1000000 OR
        pg_total_relation_size(c.oid) / 1048576 > 10240);

-- Use the above view to find shard candidates

SELECT *
  FROM v_shard_candidates
 ORDER BY total_size DESC;

-- Reset Statistics

SELECT pg_stat_statements_reset();
SELECT pg_stat_reset();

-- Load the postgres_fdw Foreign Data Wrapper

CREATE EXTENSION postgres_fdw;

-- Create a connection to a remote PostgreSQL server:

CREATE SERVER primary_db
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS ( host 'pg-primary', dbname 'pgbench');

-- Check the pg_foreign_server catalog table for this server.

SELECT srvname, srvoptions
  FROM pg_foreign_server;

-- Alter a remote PostgreSQL server

ALTER SERVER primary_db OPTIONS (ADD port '5433');
ALTER SERVER primary_db OPTIONS (SET port '5444');

-- Drop a remote PostgreSQL server

DROP SERVER primary_db CASCADE;

-- Create a user mapping

CREATE USER bench_user WITH PASSWORD 'testing';

CREATE USER MAPPING FOR bench_user 
    SERVER primary_db
    OPTIONS (user 'bench_user', password 'testing');

-- Map the postgres user for administrative creations

CREATE USER MAPPING FOR postgres 
    SERVER primary_db
    OPTIONS (user 'postgres');

-- View all known information about the user:

SELECT u.rolname AS user_name,
       s.srvname AS server_name,
       um.umoptions AS map_options
  FROM pg_user_mapping um
  JOIN pg_authid u ON (u.oid = um.umuser)
  JOIN pg_foreign_server s ON (s.oid = um.umserver);

-- Map all users!

DO $$
DECLARE
  user_name VARCHAR;
BEGIN
  FOR user_name IN
      SELECT usename FROM pg_user
  LOOP
    EXECUTE 
      'CREATE USER MAPPING FOR ' || user_name || '
      SERVER primary_db
      OPTIONS (user ' || quote_literal(user_name) || ')';
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create / Map a Foreign Table

DROP TABLE IF EXISTS pgbench_accounts;

CREATE FOREIGN TABLE pgbench_accounts
(
    aid       INTEGER NOT NULL,
    bid       INTEGER,
    abalance  INTEGER,
    filler    CHAR(84)
)
SERVER primary_db
OPTIONS (table_name 'pgbench_accounts');

ANALYZE pgbench_accounts;

GRANT ALL ON pgbench_accounts TO bench_user;

-- Import all of the pgbench tables at once...

IMPORT FOREIGN SCHEMA public
  FROM SERVER primary_db
  INTO public;

-- Fetch some basic info from the foreign table in three ways
-- to illustrate performance differences.

EXPLAIN VERBOSE
SELECT aid, bid, abalance
  FROM pgbench_accounts
 WHERE aid BETWEEN 500000 AND 500004;

EXPLAIN VERBOSE
SELECT sum(abalance) AS abalance
  FROM pgbench_accounts
 WHERE aid BETWEEN 500000 AND 500004;

EXPLAIN VERBOSE
SELECT a2.aid, a2.bid, a2.abalance
  FROM pgbench_accounts a1
  JOIN pgbench_accounts a2 USING (aid)
 WHERE a1.aid BETWEEN 500000 AND 500004

-- View to fix performance problem in last query. Create this
-- on pg-primary.

CREATE OR REPLACE VIEW v_pgbench_accounts_self_join AS
SELECT a1.aid, a2.bid, a2.abalance
  FROM pgbench_accounts a1
  JOIN pgbench_accounts a2 USING (aid)
 ORDER BY a1.aid DESC;

GRANT SELECT ON v_pgbench_accounts_self_join TO bench_user;

-- Foreign table to use the view on pg-report.
 
CREATE FOREIGN TABLE pgbench_accounts_self
(
    aid       INTEGER NOT NULL,
    bid       INTEGER,
    abalance  INTEGER
)
SERVER primary_db
OPTIONS (table_name 'v_pgbench_accounts_self_join');

GRANT SELECT ON pgbench_accounts_self TO bench_user;

-- Then use the foreign view:

EXPLAIN VERBOSE
SELECT aid, bid, abalance
  FROM pgbench_accounts_self
 WHERE aid BETWEEN 500000 AND 500004;

-- Create a materialized view

ALTER FOREIGN TABLE pgbench_accounts
      RENAME TO remote_accounts;

CREATE MATERIALIZED VIEW pgbench_accounts AS
SELECT *
  FROM remote_accounts
 WHERE bid = 5
  WITH DATA;

CREATE INDEX idx_pgbench_accounts_aid
    ON pgbench_accounts (aid);

-- Basic query plan to prove local usage + indexes:

EXPLAIN ANALYZE
 SELECT *
   FROM pgbench_accounts
  WHERE aid BETWEEN 400001 AND 400050;

-- Refresh our materialized view:

REFRESH MATERIALIZED VIEW pgbench_accounts;

-- Bootstrap an empty "shardable" schema.

CREATE SCHEMA myapp;
CREATE TABLE myapp.msg_log (
  id       SERIAL  PRIMARY KEY,
  message  TEXT    NOT NULL
);

-- Create a "shard" schema with a new nextval function.

CREATE SCHEMA shard;
CREATE SEQUENCE shard.table_id_seq;

CREATE OR REPLACE FUNCTION shard.next_unique_id(
  shard_id INT
)
RETURNS BIGINT AS
$BODY$
DECLARE
  epoch    DATE   := '2014-01-01';

  epoch_ms BIGINT;
  now_ms   BIGINT;
  next_id  BIGINT;
BEGIN
  epoch_ms = floor(
    extract(EPOCH FROM epoch) * 1000
  );

  now_ms = floor(
    extract(EPOCH FROM clock_timestamp()) * 1000
  );

  next_id = (now_ms - epoch_ms) << 22
      | (shard_id << 11)
      | (nextval('shard.table_id_seq') % 2048);

  RETURN next_id;
END;
$BODY$ LANGUAGE plpgsql;

-- Now view the contents of an ID:

SELECT (newval & 2047) AS id_value,
       (newval >> 11) & 2047 AS shard_id,
       (newval >> 22) / 1000 / 3600 / 24 AS days
  FROM (SELECT shard.next_unique_id(15)
          AS newval) nv;

-- Use our shard function in a table.

CREATE SCHEMA myapp1;

CREATE TABLE myapp1.msg_log (
    LIKE myapp.msg_log INCLUDING INDEXES
);

ALTER TABLE myapp1.msg_log
ALTER id TYPE BIGINT,
ALTER id SET DEFAULT shard.next_unique_id(1);

-- Create a logical -> physical map store:

CREATE TABLE shard.shard_map
(
  map_id         SERIAL PRIMARY KEY,
  shard_id       INT NOT NULL,
  source_schema  VARCHAR NOT NULL,
  shard_schema   VARCHAR NOT NULL,
  server_name    VARCHAR NOT NULL,
  UNIQUE (shard_id, source_schema)
);

-- Create two shards and save their location in the store:

CREATE SCHEMA myapp1;

INSERT INTO shard.shard_map 
  (shard_id, source_schema, shard_schema, server_name)
VALUES (1, 'myapp', 'myapp1', 'pg-primary');

CREATE SCHEMA myapp2;

INSERT INTO shard.shard_map 
  (shard_id, source_schema, shard_schema, server_name)
VALUES (2, 'myapp', 'myapp2', 'pg-primary');

-- View the active list of shards:

SELECT * FROM shard.shard_map;

-- Update the shard mapping:

UPDATE shard.shard_map
   SET server_name = 'pg-primary2'
 WHERE shard_schema = 'myapp2';

-- Drop unnecessary schema on pg-primary:

DROP SCHEMA myapp2;

-- Drop unnecessary schema on pg-primary2:

DROP SCHEMA myapp1;
