-- Exercise 07: the SAME query and data as exercise 07b, forced via
-- pg_hint_plan into the 2001-era plan shape the original Informix
-- case study actually produced -- join order t1 -> t2 -> t3 (FROM-
-- clause order), t2 accessed via its ORIGINAL (col1, col2, col3)
-- index (leading with the weak join key, not the 2%-selective col3).
-- Against the data created by "70 - create exercise 07.sql" (run
-- that file first).
--
-- enable_hashjoin/enable_mergejoin/enable_seqscan are turned off so
-- the only way to satisfy the join is a Nested Loop using whatever
-- index pg_hint_plan's Leading()/IndexScan() hints pin it to -- this
-- reproduces the original plan on purpose; it is not how YSQL would
-- choose to run this query on its own (see "74 - run query 07b").

\c my_db48_ex07

SET enable_hashjoin = off;
SET enable_mergejoin = off;
SET enable_seqscan = off;

/*+
  Leading(((t1 t2) t3))
  NestLoop(t1 t2)
  NestLoop(t1 t2 t3)
  IndexScan(t1 t1_pkey)
  IndexScan(t2 idx_t2_col1_col2_col3)
  IndexScan(t3 t3_pkey)
*/
EXPLAIN (ANALYZE, BUFFERS)
SELECT t1.col1, t1.col2, t2.col3, t3.col1
FROM t1, t2, t3
WHERE t1.col1 = 'LA'
  AND t1.col2 = t2.col1
  AND t2.col3 = 'FLT-00025'
  AND t2.col3 = t3.col1;

-- VERIFIED RESULT: the hints worked -- this successfully reproduces
-- the 2001-era plan shape on demand, even with t1 reduced to its one
-- true index (see "70"'s comment -- the earlier version of this
-- exercise accidentally gave t1 a second, single-column index that
-- the real case study's table never had).
--
--   YB Batched Nested Loop Join
--     -> Index Scan using t1_pkey on t1
--          Index Cond: (col1 = 'LA')              -- 68,600 rows (98%)
--     -> Index Scan using idx_t2_col1_col2_col3 on t2
--          Index Cond: (col1 = ANY ARRAY[...] AND col3 = 'FLT-00025')
--   -> Materialize -> Index Scan using t3_pkey on t3   -- loops=1900
--
-- Driving from t1's near-useless filter (98% of the table) instead of
-- t3's highly selective one, exactly like the original case study.
-- Note t3 now gets probed once per surviving row (loops=1900,
-- Materialize keeps it cheap) instead of once overall -- a direct
-- consequence of forcing t1 to be first instead of last.
--
-- Execution Time: steady at ~385-395ms across repeated runs. Compare
-- to "74 - run query 07b" (same data, no hints): ~37-43ms. Forcing
-- the 2001-era plan shape via hints costs roughly 9-10x here --
-- real and measurable, just nowhere near the original "3 to 5
-- minutes" -- see "74"'s own comment for why that gap in DEGREE
-- (not existence) is itself the interesting finding.
