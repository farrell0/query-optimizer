-- Exercise 05b: same logical result as exercise 05 (all 10 columns
-- for every entity with at least one 'active' t2 event), but joining
-- to t3 -- which already has exactly one row per qualifying entity --
-- instead of joining to t2 directly and de-duplicating with DISTINCT.
--
-- No DISTINCT, no Sort, no HashAggregate -- t3's own primary key
-- guarantees at most one match per t1 row, so the join itself can
-- never produce duplicates in the first place.

\c my_db48_ex05

EXPLAIN (ANALYZE)
SELECT t1.col1, t1.col2, t1.col3, t1.col4, t1.col5,
       t1.col6, t1.col7, t1.col8, t1.col9, t1.col10
FROM t1
JOIN t3 ON t1.col1 = t3.col1;
