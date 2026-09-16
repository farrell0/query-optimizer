

-- Exercise 01 setup: two tables sized so the planner has a real join
-- strategy to choose between --
--    t1: 100,000 rows, col1 unique (1..100,000) -- the join/lookup key
--    t2: 1,000,000 rows, col1 cycles 1..100,000 -- 10 matching rows in
--        t2 for every value of t1.col1
--
-- Runs in its own database (my_db48_ex01) so it never touches the live
-- query-plan-management demo's own `t1` table in `my_db48`.


SELECT 'CREATE DATABASE my_db48_ex01'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex01')
\gexec

\c my_db48_ex01

DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t1;

-- Explicit HASH primary key (YugabyteDB's preferred PK syntax) rather
-- than the bare "col1 INT PRIMARY KEY" shorthand, which defaults to a
-- range-sharded (ASC) index here. col1 is a monotonically increasing
-- sequence (1..100,000) -- range sharding on that would hotspot writes
-- onto one tablet range at a time; hashing spreads rows evenly across
-- tablets by hash(col1) instead.
CREATE TABLE t1 (
   col1  INT,
   col2  INT,
   col3  TEXT,
   PRIMARY KEY (col1 HASH)
);

-- 100,000 rows, col1 = 1..100,000 (unique -- the join key)
INSERT INTO t1 (col1, col2, col3)
SELECT g, 1 + (g % 1000), repeat('x', 50)
FROM generate_series(1, 100000) AS g;

-- Composite primary key (col1, col2): col1 carries the equality
-- join/filter (t1.col1 = t2.col1 = 5), col2 the range filter (> 5) --
-- putting both in the PK lets the planner satisfy the WHERE clause with
-- a single index scan instead of a 1,000,000-row seq scan, AND return
-- rows already in col2 order within that col1 value, which can let it
-- skip the separate Sort step for "order by t2.col2" too.
--
-- col1 leads with HASH for the same reason as t1's PK above -- its
-- generator cycles 1..100,000 repeatedly, so a range-sharded leading
-- column would hit tablets in the same moving-sequential-hotspot
-- pattern. col2 stays ASC (range): the col2-sorted-within-a-col1-value
-- guarantee this key exists for lives inside each hash bucket, so
-- hashing col1 doesn't disturb it.
--
-- (col1, col2) is guaranteed unique by construction below -- the 10
-- rows sharing a given col1 land 100,000 generate_series steps apart,
-- and 100,000 mod 997 (col2's modulus, chosen prime) is nonzero, so
-- those 10 rows' col2 values never collide.
CREATE TABLE t2 (
   col1  INT,
   col2  INT,
   col3  TEXT,
   PRIMARY KEY (col1 HASH, col2 ASC)
);

-- 1,000,000 rows, col1 cycles 1..100,000 so every t1.col1 value has
-- exactly 10 matching rows in t2 -- guarantees the exercise query's join
-- actually returns rows (t1.col1 = 5 alone matches 10 rows in t2).
--
-- col2 uses modulus 997 (prime), NOT 1000: 1000 divides evenly into
-- 100,000, so a col1-cycle-aligned modulus for col2 would make col2
-- fully determined by col1 -- every row sharing a col1 value would get
-- the identical col2 value, and "t2.col2 > 5" would then either match
-- all or none of them instead of a realistic subset.
INSERT INTO t2 (col1, col2, col3)
SELECT 1 + (g % 100000), 1 + (g % 997), repeat('x', 50)
FROM generate_series(1, 1000000) AS g;

ANALYZE t1;
ANALYZE t2;



