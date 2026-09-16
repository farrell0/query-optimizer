-- Exercise 04 setup: a simple two-table OUTER join. t1 is the OUTER
-- (preserved) side of a LEFT OUTER JOIN -- every t1 row appears in
-- the result whether or not it has a match. t2 is the INNER
-- (joined-to) side -- only matching rows contribute real values;
-- unmatched t1 rows get t2's columns NULL-extended.
--
-- t1: 100,000 rows, col1 unique 1..100,000.
-- t2: only 10,000 rows, col1 = 1..10,000 -- so 90% of t1 rows have NO
-- match in t2, making this a genuine outer join (not one that could
-- just as well have been an inner join).
--
-- Follows the my_db48_exNN naming convention from exercises 01-03.

SELECT 'CREATE DATABASE my_db48_ex04'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex04')
\gexec

\c my_db48_ex04

DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t1;

CREATE TABLE t1 (
   col1  INT,
   col2  INT,
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t1 (col1, col2)
SELECT g, g * 2
FROM generate_series(1, 100000) AS g;

CREATE TABLE t2 (
   col1  INT,
   col2  INT,
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t2 (col1, col2)
SELECT g, g * 3
FROM generate_series(1, 10000) AS g;

ANALYZE t1;
ANALYZE t2;


