-- Exercise 06: the "two correlated scalar subqueries per outer row"
-- pattern. Against the data created by "60 - create exercise 06.sql"
-- (run that file first). For each of the 5,000 t1 rows in 'West',
-- the COUNT(*) subquery and the SUM(t2.col3) subquery each probe t2
-- independently via idx_t2_col2 -- 10,000 total index probes into t2,
-- not one pass over it.

\c my_db48_ex06

EXPLAIN (ANALYZE, BUFFERS)
SELECT t1.col1, t1.col2,
       (SELECT COUNT(*) FROM t2 WHERE t2.col2 = t1.col1) AS row_count,
       (SELECT SUM(t2.col3) FROM t2 WHERE t2.col2 = t1.col1) AS total_val
FROM t1
WHERE t1.col2 = 'West';

-- VERIFIED RESULT: Seq Scan on t1 (5,000 'West' rows), with each row
-- re-executing BOTH subplans -- a Finalize/Index Only Scan for the
-- COUNT and a separate Aggregate/Index Scan for the SUM -- each doing
-- its own probe of idx_t2_col2 (loops=5000 on each). 10,000 total
-- index probes into t2 for 5,000 outer rows. Execution Time: ~16.2s.
-- See "64 - run query 06b with explain.sql" for the single-pass
-- alternative and the resulting speedup.
