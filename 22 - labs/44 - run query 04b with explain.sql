-- Exercise 04b: same query and data as exercise 04, but with hash and
-- merge joins disabled so the planner has to use a Nested Loop --
-- showing explicitly that t1 (the OUTER/preserved table) drives the
-- loop, reading first, and joins INTO t2 (the INNER table), which is
-- probed per t1 row/batch. Run "40 - create exercise 04.sql" first if
-- you haven't.
--
-- This is the natural, and only valid, direction for a Nested Loop
-- implementing LEFT OUTER JOIN -- see "42 - run query 04 with
-- explain.sql" for the companion test proving the reverse (t2 driving
-- into t1) isn't achievable, even with an explicit pg_hint_plan
-- Leading() hint.

\c my_db48_ex04

SET enable_hashjoin = off;
SET enable_mergejoin = off;

EXPLAIN (ANALYZE)
SELECT *
FROM t1
LEFT OUTER JOIN t2 ON t1.col1 = t2.col1;

-- VERIFIED RESULT:
--   YB Batched Nested Loop Left Join
--     ->  Seq Scan on t1              -- outer/driving side, read first
--     ->  Index Scan using t2_pkey on t2   -- inner side, probed per batch
--           Index Cond: (col1 = ANY (ARRAY[t1.col1, $1, $2, ..., $1023]))
