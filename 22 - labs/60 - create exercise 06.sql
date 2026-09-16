-- Exercise 06 setup: the classic "N correlated scalar subqueries per
-- outer row" pattern. t1 is the "one side" (e.g. customers); t2 is
-- the "many side" (e.g. orders), referenced back to t1 via col2. The
-- query in exercise 06 runs TWO correlated subqueries (a COUNT and a
-- SUM) against t2 for every qualifying t1 row -- one probe of t2 per
-- row, per subquery, instead of one pass over t2 total.
--
-- t1: 20,000 rows, evenly split across 4 categories in col2 -- so
-- filtering to a single category (WHERE t1.col2 = 'West') still
-- leaves 5,000 rows, each needing its own pair of correlated probes.
-- t2: 100,000 rows, col2 cycling through all 20,000 t1 entities --
-- ~5 rows per t1 entity on average, aggregated by the subqueries.
--
-- Follows the my_db48_exNN naming convention from exercises 01-05.

SELECT 'CREATE DATABASE my_db48_ex06'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex06')
\gexec

\c my_db48_ex06

DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t1;

-- t1 = the "one side" table (e.g. customers), 20,000 rows
CREATE TABLE t1 (
   col1  INT,       -- entity id
   col2  TEXT,       -- category/region, used as a filter
   PRIMARY KEY (col1 HASH)
);

-- 20,000 rows into t1, evenly split across 4 categories
INSERT INTO t1 (col1, col2)
SELECT g,
       CASE WHEN g % 4 = 0 THEN 'West'
            WHEN g % 4 = 1 THEN 'East'
            WHEN g % 4 = 2 THEN 'North'
            ELSE 'South' END
FROM generate_series(1, 20000) g;

-- t2 = the "many side" table (e.g. orders), 100,000 rows
CREATE TABLE t2 (
   col1  INT,             -- row id
   col2  INT,             -- foreign key back to t1.col1
   col3  NUMERIC(10,2),   -- a numeric value to aggregate
   PRIMARY KEY (col1 HASH)
);

-- 100,000 rows into t2, ~5 rows per t1 entity on average
INSERT INTO t2 (col1, col2, col3)
SELECT g, ((g % 20000) + 1), (random() * 500)::numeric(10,2)
FROM generate_series(1, 100000) g;

CREATE INDEX idx_t2_col2 ON t2 (col2 ASC);

ANALYZE t1;
ANALYZE t2;
