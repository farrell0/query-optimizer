-- Distribution-effect follow-up to exercise 03c: same table (t3),
-- same index (t3_col1_trgm_idx), same TECHNIQUE -- but the common
-- suffix instead of the rare one. 'LE WA' matches 400,000 of
-- 1,000,000 rows (40% selectivity, verified via a direct count), vs.
-- 'GE AK' at 5,000 rows (0.5%).
--
-- This isolates the one thing that changed between exercise 03c and
-- here: how common the search text is in the data -- not the table,
-- not the index, not the query shape. Compare this file's timing and
-- "Rows Removed by Index Recheck" against 03c's to see textual
-- distribution's effect on run time, independent of which indexing
-- technique is used.
--
-- VERIFIED RESULTS (full picture, all 3 techniques, both predicates):
--
--                    'GE AK' rare (0.5%)   'LE WA' common (40%)
--    Seq Scan              257 ms                1,075 ms
--    Reverse index (03b)    42.5 ms              2,673 ms
--    GIN trigram (03c)    4,189 ms                2,125 ms
--
-- Two real, verified lessons, not the naive "indexes always win" one:
--   1. For the RARE predicate, reverse-index wins decisively and GIN
--      is worse than doing nothing (see 03's comments -- weak
--      short-word trigrams).
--   2. For the COMMON predicate, plain Seq Scan wins outright -- both
--      indexed techniques are SLOWER than scanning the whole table.
--      At 40% selectivity, the per-row cost of walking an index and
--      fetching matches individually exceeds the cost of one
--      straight sequential pass. Indexing isn't free, and a
--      sufficiently unselective predicate can make ANY index a net
--      loss, regardless of technique.

\c my_db48_ex03

EXPLAIN (ANALYZE)
SELECT * FROM t3 WHERE col1 LIKE '%LE WA';


