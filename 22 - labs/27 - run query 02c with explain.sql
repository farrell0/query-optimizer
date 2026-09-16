-- Exercise 02c: same query, same data as exercise 02b, but work_mem set
-- low enough that this 100,000-row sort no longer fits in memory --
-- YSQL switches from "Sort Method: quicksort" to "Sort Method:
-- external merge", spilling intermediate sort data to disk.
--
-- 4MB is PostgreSQL's (and YSQL's) actual out-of-the-box default --
-- this sort already spills at the default, before anyone deliberately
-- shrinks anything.

\c my_db48_ex02

SET work_mem = '4MB';

EXPLAIN (ANALYZE)
select *
from t1
order by
      col2;


