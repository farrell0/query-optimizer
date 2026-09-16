-- Exercise 01b: same data as exercise 01 (run "10 - create exercise 01
-- .sql" first if you haven't) -- this shows the case where a manual
-- Sort IS required, even with t2's composite primary key in place.
--
-- The composite key (col1 HASH, col2 ASC) only returns rows in col2
-- order WITHIN a single col1 value. Exercise 01's query pins col1 to
-- exactly one value (= 5), so that per-group order happens to already
-- be the global order the client asked for -- no separate sort step
-- needed.
--
-- Here the filter covers three col1 values (5, 6, 7) instead of one.
-- The index scan now returns three blocks (all col1=5, then col1=6,
-- then col1=7), each internally sorted by col2 -- but the blocks
-- themselves are NOT merged into one col2-sorted sequence. So YSQL adds
-- an explicit Sort node to produce the "order by t2.col2" the query
-- asked for.

\c my_db48_ex01

EXPLAIN (ANALYZE)
select *
from t1, t2
where
      t1.col1 = t2.col1
and
      t1.col1 in (5, 6, 7)
and
      t2.col2 > 5
order by
      t2.col2;


