-- Exercise 03c: pg_trgm GIN trigram index -- this is the technique the
-- reference material at "15 - Clients/15 - US Bank/22 - Query 03"
-- actually uses in production. A trigram index breaks text into
-- overlapping 3-character sequences and indexes those, so unlike the
-- reverse-index trick, it can accelerate LIKE patterns with wildcards
-- in the MIDDLE too (e.g. '%Yumm%Donut%'), not just a fixed suffix.
--
-- Uses its own table (t3), same reasoning as t2 in 03b: each example
-- needs to be isolated so running one doesn't change another's
-- result. An earlier version of this file added the GIN index
-- directly to t1 -- that meant exercise 03's "no index" baseline
-- (file 32) silently started using the GIN index too, the moment
-- this file had ever been run. t3 is a copy of the SAME data as
-- t1/t2 (same database, my_db48_ex03) -- run "30 - create exercise
-- 03.sql" first if you haven't.

\c my_db48_ex03

DROP TABLE IF EXISTS t3;

CREATE TABLE t3 (
   id    BIGINT,
   col1  TEXT,
   PRIMARY KEY (id HASH)
);

INSERT INTO t3 (id, col1)
SELECT id, col1 FROM t1;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX t3_col1_trgm_idx ON t3 USING gin (col1 gin_trgm_ops);

ANALYZE t3;


