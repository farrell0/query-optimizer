-- Exercise 03: baseline EXPLAIN for a suffix-match LIKE query, against
-- the data created by "30 - create exercise 03.sql" (run that file
-- first). No supporting index -- col1's only index is the id primary
-- key, which can't help a predicate on col1.
--
-- 'GE AK' is the rare case: only 5,000 of 1,000,000 rows end with
-- "ANCHORAGE AK" (0.5% selectivity, verified via a direct count).
-- Even so, with no index at all, YSQL still has to sequentially scan
-- and pattern-match every one of the 1,000,000 rows to find those 5,000
-- -- selectivity of the RESULT doesn't help a query that can't use an
-- index in the first place.

\c my_db48_ex03

EXPLAIN (ANALYZE)
SELECT * FROM t1 WHERE col1 LIKE '%GE AK';


