-- Exercise 01: baseline EXPLAIN for the join query, against the data
-- created by "10 - create exercise 01.sql" (run that file first).
--
-- Exercise 01 EXPLAIN -- just the plan tree (which access method was
-- picked per table: Seq Scan vs Index Scan, and the join method) plus
-- actual run time per node, with none of the storage/buffers noise.
-- Add DIST, BUFFERS, VERBOSE, SUMMARY back in once that's familiar and
-- you want real storage-call numbers alongside the plan.

\c my_db48_ex01

EXPLAIN (ANALYZE)
select *
from t1, t2
where
      t1.col1 = t2.col1
and
      t1.col1 = 5
and
      t2.col2 > 5
order by
      t2.col2;




