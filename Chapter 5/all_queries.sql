-- Create the nagios user for monitoring.

CREATE USER nagios;

-- Create the perf_mon user for performance monitoring.

CREATE USER perf_mon WITH PASSWORD 'testpw';

-- Create a big table for testing

CREATE TABLE bigtable AS
SELECT generate_series(1,1000000) AS vals;
