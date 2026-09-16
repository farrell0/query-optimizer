-- Schema for the query plan management demonstration.
-- Created only if not already present; the application always re-runs
-- ANALYZE on startup regardless, to keep planner statistics current.

CREATE TABLE t1 (
   id           bigint PRIMARY KEY,
   customer_id  int,
   payload      text
);

-- 500 "typical" customers, ~100 rows each (~50,000 rows)
INSERT INTO t1 (id, customer_id, payload)
SELECT g, 1 + (g % 500), repeat('x', 50)
FROM generate_series(1, 50000) AS g;

-- 3 "mega" customers (9001, 9002, 9003), 150,000 rows each (~450,000 rows)
INSERT INTO t1 (id, customer_id, payload)
SELECT 50000 + g, 9000 + (g % 3) + 1, repeat('x', 50)
FROM generate_series(1, 450000) AS g;

CREATE INDEX t1_customer_idx ON t1 (customer_id);

ANALYZE t1;
