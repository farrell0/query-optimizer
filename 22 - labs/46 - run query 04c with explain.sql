-- Exercise 04c: same data and same LEFT OUTER JOIN as exercises 04 /
-- 04b, but with a filter that shrinks t1 from 100,000 rows down to
-- ~100 before the join. Run "40 - create exercise 04.sql" first if
-- you haven't.
--
-- Exercise 04's unfiltered join naturally picked Hash Left Join
-- (build a hash table over all of t2, then stream all of t1 through
-- it). This tests whether shrinking the OUTER/driving side changes
-- that choice -- it does, with no hints or GUCs needed.

\c my_db48_ex04

EXPLAIN (ANALYZE)
SELECT *
FROM t1
LEFT OUTER JOIN t2 ON t1.col1 = t2.col1
WHERE t1.col1 <= 100;

-- VERIFIED RESULT: planner naturally switches to
-- YB Batched Nested Loop Left Join (Seq Scan + Storage Filter on t1
-- down to 100 rows, then Index Scan against t2_pkey per batch) --
-- Execution Time ~33ms.
--
-- FOLLOW-UP TESTED: forcing Hash Join on this same filtered query
-- (SET enable_nestloop = off; SET yb_enable_batchednl = off;) --
-- note BOTH GUCs are needed, since YugabyteDB's batched nested loop
-- has its own separate switch from standard enable_nestloop.
--
-- Forced result: Hash Right Join -- the optimizer is smart enough to
-- flip which side gets hashed (builds the hash from the small,
-- filtered t1 side now, not t2), proving the cost model already
-- accounts for "building a hash table isn't free." But it STILL has
-- to Seq Scan all 10,000 rows of t2 as the streamed side -- a hash
-- join always reads the entire non-hashed side, there's no way to
-- skip its irrelevant rows the way an index-driven Nested Loop can.
-- Execution Time ~43ms -- slower than the natural Batched Nested Loop
-- choice above, even in this "smart" arrangement.
--
-- The crossover: with all 100,000 t1 rows needing probes (exercise
-- 04), ~100,000 individual (batched) index lookups against t2 cost
-- more in aggregate than one full sequential read of t2 plus a hash
-- build. Shrink the outer/driving side to ~100 rows and that flips --
-- a handful of targeted index lookups beats reading all of t2 at all,
-- hash table or not.
