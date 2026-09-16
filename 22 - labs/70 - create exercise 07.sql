-- Exercise 07 setup: anonymized from a real customer case study (see
-- "02 - Files/88 - NACU/Query Case Study.pdf") -- t1 (col1 near-
-- constant "location code", col2 truly unique), t2 (col1 = weak join
-- key back to t1, col3 = the truly selective 2% filter and join key
-- to t3), t3 (clean unique lookup, "was fine" in the original case
-- study). t1 and t3 carry unused col3-col8 padding, echoing the real
-- table widths (146/7/54 columns) -- t2 (the "middle" table) is left
-- narrow on purpose, same as the case study's own table "b". Same
-- ORIGINAL (customer-reported, suboptimal) index shapes as the case
-- study itself:
--
--   t1: t1_pkey (col1 HASH, col2 ASC)                    -- leads weak
--   t2: idx_t2_col1_col2_col3 (col1 HASH, col2 ASC, col3 ASC) -- leads weak
--
-- t1 has exactly ONE index -- its primary key IS the (col1, col2)
-- composite, matching the case study's table "a" exactly. An earlier
-- version of this exercise gave t1 a second, single-column surrogate
-- key (col2 HASH) purely out of habit -- that accidentally handed the
-- optimizer an escape hatch for the t1.col2 = t2.col1 join that the
-- real table never had. Removed; see "72"/"74"'s own comments for
-- what changed (and what didn't) once it was gone.
--
-- Three query variants run against this same data:
--   07  -- forced, via pg_hint_plan, into the 2001-era plan shape:
--         join order t1 -> t2 -> t3, t2 accessed via its ORIGINAL
--         (col1, col2, col3) index -- deliberately reproducing what
--         the original Informix optimizer picked on its own.
--   07b -- the exact same query and data, NO hints -- whatever YSQL's
--         cost-based optimizer chooses naturally, unmodified indexes.
--   07c -- (own setup, "76") -- same query against isolated copies
--         with the case study's actual fix (indexes reordered to lead
--         with the truly selective column).
--
-- Follows the my_db48_exNN naming convention from exercises 01-06.

SELECT 'CREATE DATABASE my_db48_ex07'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex07')
\gexec

\c my_db48_ex07

CREATE EXTENSION IF NOT EXISTS pg_hint_plan;

DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t3;

-- t1 -- 70,000 rows. col1 ('LA') covers 98% of rows -- filtering on
-- it alone is nearly useless, even though it's the leading column of
-- a UNIQUE composite index (uniqueness here actually comes entirely
-- from col2). ONE index only, matching the original case study's
-- table "a" exactly -- no separate surrogate key on col2 alone. That
-- matters: a standalone col2 index would hand the optimizer an
-- escape hatch for the t1.col2 = t2.col1 join that the real table
-- never had.
--
-- col3-col8 are unused padding -- present but never referenced by any
-- query here -- echoing the case study's own table "a" (146 real
-- columns; the query only ever touched 2 of them).
CREATE TABLE t1 (
   col1  TEXT,
   col2  TEXT,
   col3  INT,
   col4  TEXT,
   col5  TEXT,
   col6  TIMESTAMP,
   col7  NUMERIC(10,2),
   col8  TEXT,
   PRIMARY KEY (col1 HASH, col2 ASC)
);

INSERT INTO t1 (col1, col2, col3, col4, col5, col6, col7, col8)
SELECT
   CASE WHEN g % 50 = 0 THEN 'NY' ELSE 'LA' END,
   'KEY-' || lpad(g::text, 10, '0'),
   g % 1000,
   'name_' || g,
   'category_' || (g % 20),
   TIMESTAMP '2025-01-01' + (g % 365) * INTERVAL '1 day',
   (g % 10000) / 100.0,
   'ref_' || (g % 500)
FROM generate_series(1, 70000) g;

-- t2 -- 95,000 rows. col1 joins back to t1.col2 (~1.36 rows per t1
-- row on average -- not selective by itself). col3 has exactly 50
-- distinct values, so col3 = one literal passes exactly 2% of the
-- table.
CREATE TABLE t2 (
   id    BIGINT,
   col1  TEXT,
   col2  SMALLINT,
   col3  TEXT,
   PRIMARY KEY (id HASH)
);

INSERT INTO t2 (id, col1, col2, col3)
SELECT
   g,
   'KEY-' || lpad((((g - 1) % 70000) + 1)::text, 10, '0'),
   (g % 100)::smallint,
   'FLT-' || lpad(((g % 50) + 1)::text, 5, '0')
FROM generate_series(1, 95000) g;

-- ORIGINAL secondary index -- leads with col1 (the join key from t1,
-- weak selectivity), not col3 (2% selectivity, the real filter).
CREATE INDEX idx_t2_col1_col2_col3 ON t2 (col1 HASH, col2 ASC, col3 ASC);

-- t3 -- 55,000 rows, unique lookup key. Includes 'FLT-00001' through
-- 'FLT-00050' (t2.col3's full value space) among its 55,000 keys.
-- col2-col8 are unused padding, same reasoning as t1's -- echoing the
-- case study's table "c" (54 real columns, only col1 ever queried).
CREATE TABLE t3 (
   col1  TEXT,
   col2  TEXT,
   col3  INT,
   col4  TEXT,
   col5  TEXT,
   col6  TIMESTAMP,
   col7  NUMERIC(10,2),
   col8  TEXT,
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t3 (col1, col2, col3, col4, col5, col6, col7, col8)
SELECT
   'FLT-' || lpad(g::text, 5, '0'),
   'aux_' || g,
   g % 1000,
   'name_' || g,
   'category_' || (g % 20),
   TIMESTAMP '2025-01-01' + (g % 365) * INTERVAL '1 day',
   (g % 10000) / 100.0,
   'ref_' || (g % 500)
FROM generate_series(1, 55000) g;

ANALYZE t1;
ANALYZE t2;
ANALYZE t3;
