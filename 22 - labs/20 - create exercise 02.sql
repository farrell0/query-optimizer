-- Exercise 02 setup: same t1 shape as exercise 01 (100,000 rows, col1
-- unique 1..100,000, col2 = 1 + (row % 1,000)), but in its OWN database
-- (my_db48_ex02) -- exercises 01/01b live in my_db48_ex01, so each
-- numbered range of files gets its own database and none of them can
-- collide with each other.
--
-- Query 02 filters on col1 OR col2 -- two DIFFERENT columns. col1
-- already has an index (its HASH primary key); this adds one for col2
-- too, on purpose, so BOTH sides of the OR are indexed -- see
-- "22 - run query 02 with explain.sql" for what YugabyteDB does with
-- that (a BitmapOr combining one Bitmap Index Scan per column).

SELECT 'CREATE DATABASE my_db48_ex02'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex02')
\gexec

\c my_db48_ex02

DROP TABLE IF EXISTS t1;

-- Explicit HASH primary key -- see "10 - create exercise 01.sql" for
-- why (col1 is a monotonically increasing sequence; hashing avoids a
-- moving-sequential-hotspot on writes).
CREATE TABLE t1 (
   col1  INT,
   col2  INT,
   col3  TEXT,
   PRIMARY KEY (col1 HASH)
);

-- 100,000 rows, col1 = 1..100,000 (unique), col2 = 1..1,000 (repeating)
-- -- ~100 rows match col2 = 20, plus the single col1 = 10 row.
INSERT INTO t1 (col1, col2, col3)
SELECT g, 1 + (g % 1000), repeat('x', 50)
FROM generate_series(1, 100000) AS g;

-- col2 has the same repeating-cycle shape as col1, so HASH here too --
-- same write-hotspot reasoning as everywhere else in this lab.
CREATE INDEX t1_col2_idx ON t1 (col2 HASH);

ANALYZE t1;


