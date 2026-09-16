-- Exercise 05b: instead of paying DISTINCT's cost on every query,
-- record the "which entities qualify" fact ONCE, in its own table,
-- and query that table directly -- since t3 has one row per
-- qualifying entity BY CONSTRUCTION (its own primary key enforces
-- it), no DISTINCT is ever needed against it.
--
-- t3 is built here via the exact same SELECT DISTINCT as exercise
-- 05's query -- the cost doesn't disappear, it moves to this ONE
-- setup step instead of being paid by every future query. That's the
-- real trade-off this exercise demonstrates, not "DISTINCT is free
-- now." A real system would maintain t3 incrementally (a trigger on
-- t2, or a periodic refresh), not necessarily rebuild it from scratch
-- like this script does for the lab.
--
-- Run "50 - create exercise 05.sql" first if you haven't -- reuses
-- t1/t2 from there.

\c my_db48_ex05

DROP TABLE IF EXISTS t3;

CREATE TABLE t3 (
   col1  INT,
   PRIMARY KEY (col1 HASH)
);

INSERT INTO t3 (col1)
SELECT DISTINCT col1 FROM t2 WHERE status = 'active';

ANALYZE t3;
