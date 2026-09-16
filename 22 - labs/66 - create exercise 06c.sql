-- Exercise 06c setup: exercise 06b's CTE/GROUP BY plan, but backed by
-- a COVERING index -- (col2 ASC) INCLUDE (col3) -- so YugabyteDB can
-- satisfy the whole aggregation via an Index Only Scan (Heap Fetches:
-- 0) instead of a Seq Scan of the base table. With the group key
-- already delivered in sorted order by the index, the planner also
-- switches from a HashAggregate to a streaming GroupAggregate -- no
-- hash table, so no work_mem/disk-spill exposure regardless of size.
--
-- Uses its own copy of t2 (as t3), same reasoning as exercise 03c:
-- adding the covering index directly to t2 would silently change
-- exercise 06/06b's already-captured baseline plans the next time
-- those scripts are re-run against this same database. t3 is an
-- exact copy of t2's data (same database, my_db48_ex06).
--
-- Run "60 - create exercise 06.sql" first if you haven't.

\c my_db48_ex06

DROP TABLE IF EXISTS t3;

CREATE TABLE t3 (
   col1  INT,
   col2  INT,
   col3  NUMERIC(10,2),
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t3 (col1, col2, col3)
SELECT col1, col2, col3 FROM t2;

CREATE INDEX idx_t3_col2_covering ON t3 (col2 ASC) INCLUDE (col3);

ANALYZE t3;
