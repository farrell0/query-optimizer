-- Exercise 05 setup: the classic "add SELECT DISTINCT because the
-- join produced duplicates" scenario. t1 is a wide, 10-column entity
-- table (customer-like); t2 is a one-to-many "events" table (10
-- events per t1 entity). Joining t1 to t2 and filtering on t2 alone
-- naturally duplicates each t1 row once per matching event -- the
-- usual reason people reach for DISTINCT instead of fixing the query
-- shape.
--
-- t1: 100,000 rows, 10 columns, col10 a long TEXT (~200 chars) --
-- DISTINCT has to compare/hash all 10 columns of every row, so a wide
-- row makes the cost of doing this the "easy" way much more visible.
-- t2: 1,000,000 rows, 10 per t1 entity, ~1/3 marked 'active' -- with
-- 10 trials at ~33% each, nearly every entity has at least one
-- 'active' event, but MOST have several -- exactly the shape that
-- causes heavy duplication in a naive join.
--
-- Follows the my_db48_exNN naming convention from exercises 01-04.

SELECT 'CREATE DATABASE my_db48_ex05'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex05')
\gexec

\c my_db48_ex05

DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t1;

CREATE TABLE t1 (
   col1   INT,
   col2   INT,
   col3   INT,
   col4   TEXT,
   col5   TEXT,
   col6   INT,
   col7   TIMESTAMP,
   col8   NUMERIC,
   col9   TEXT,
   col10  TEXT,
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t1 (col1, col2, col3, col4, col5, col6, col7, col8, col9, col10)
SELECT
   g,
   g % 1000,
   g % 50,
   'name_' || g,
   'category_' || (g % 20),
   g % 7,
   TIMESTAMP '2026-01-01' + (g % 365) * INTERVAL '1 day',
   (g % 10000) / 100.0,
   'ref_' || (g % 500),
   repeat('The quick brown fox jumps over the lazy dog. ', 5) || 'entity #' || g
FROM generate_series(1, 100000) AS g;

CREATE TABLE t2 (
   id      BIGINT,
   col1    INT,
   status  TEXT,
   PRIMARY KEY (id HASH)
);

-- col1 cycles through all 100,000 t1 entities 10 times -- exactly 10
-- events per entity. status is 'active' for roughly 1 in 3 events.
INSERT INTO t2 (id, col1, status)
SELECT
   g,
   ((g - 1) % 100000) + 1,
   CASE WHEN g % 3 = 0 THEN 'active' ELSE 'inactive' END
FROM generate_series(1, 1000000) AS g;

CREATE INDEX t2_col1_idx ON t2 (col1 HASH);

ANALYZE t1;
ANALYZE t2;
