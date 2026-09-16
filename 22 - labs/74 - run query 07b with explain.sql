-- Exercise 07b: the exact same query and data as exercise 07, with NO
-- hints and NO session-level planner restrictions -- whatever YSQL's
-- cost-based optimizer chooses on its own, against the ORIGINAL
-- (unmodified, customer-reported) index shapes. Against the data
-- created by "70 - create exercise 07.sql" (run that file first) --
-- this reuses the SAME t1/t2/t3 as exercise 07 read-only; nothing
-- here alters the schema, so 07 and 07b can be run in either order,
-- any number of times, without affecting each other's result.

\c my_db48_ex07

EXPLAIN (ANALYZE, BUFFERS)
SELECT t1.col1, t1.col2, t2.col3, t3.col1
FROM t1, t2, t3
WHERE t1.col1 = 'LA'
  AND t1.col2 = t2.col1
  AND t2.col3 = 'FLT-00025'
  AND t2.col3 = t3.col1;

-- VERIFIED RESULT: given the exact same (unmodified, "bad") indexes
-- as exercise 07 -- including t1 reduced to its ONE true index (col1
-- HASH, col2 ASC), no separate surrogate key on col2 alone -- YSQL's
-- cost-based optimizer, with no hints at all, still drives from t3
-- (the cheap, highly selective point lookup) FIRST, and for t2 still
-- doesn't attempt the badly-ordered (col1, col2, col3) index -- it
-- chooses a plain Seq Scan with col3 as a Storage Filter instead,
-- because its cost model already knows col3 is far more selective
-- than the index shape would suggest. Execution Time: steady at
-- ~37-43ms.
--
-- Removing t1's extra single-column index (present in an earlier
-- version of this exercise, absent from the real case study's table
-- "a") changed exactly one thing: t1's own access step now pushes
-- BOTH col1 = 'LA' and the batched col2 array into a single Index
-- Cond on t1_pkey (col1 HASH, col2 ASC) --
--   Index Cond: ((col2 = ANY (ARRAY[...])) AND (col1 = 'LA'))
-- -- instead of col1 landing as a late Storage Filter the way it did
-- when a competing col2-only index existed. With only one index
-- available, the optimizer simply uses it fully; it doesn't need a
-- second index to do that. Net effect on Execution Time: negligible
-- (~37-43ms here vs. ~34-38ms with the extra index) -- the escape
-- hatch we removed was never what made this query fast.
--
-- The 2001-era disaster still requires BOTH a bad index AND an
-- optimizer that can't see past it. Modern YSQL, with real
-- statistics, supplies neither half on its own -- it takes deliberate
-- hints (see "72 - run query 07") to force the bad behavior back into
-- existence.
