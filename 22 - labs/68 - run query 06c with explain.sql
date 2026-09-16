-- Exercise 06c: same logical query as exercise 06b, but aggregating
-- over t3 (a copy of t2 with a COVERING index -- col2 ASC INCLUDE
-- col3) instead of t2 directly. Against the data created by "60 -
-- create exercise 06.sql" and "66 - create exercise 06c.sql" (run
-- both first).

\c my_db48_ex06

EXPLAIN (ANALYZE, BUFFERS)
WITH agg AS (
    SELECT col2 AS entity_id, COUNT(*) AS row_count, SUM(col3) AS total_val
    FROM t3
    GROUP BY col2
)
SELECT t1.col1, t1.col2, agg.row_count, agg.total_val
FROM t1
JOIN agg ON agg.entity_id = t1.col1
WHERE t1.col2 = 'West';

-- VERIFIED RESULT: GroupAggregate driven by an Index Only Scan on
-- idx_t3_col2_covering -- Heap Fetches: 0, no HashAggregate, no
-- work_mem/disk-spill exposure at any size. Execution Time: ~146ms
-- across repeated runs against this freshly created t3, vs. ~166ms
-- for exercise 06b's Seq Scan + HashAggregate over t2 (~137ms with
-- work_mem raised to 64MB), and ~16.2s for exercise 06's per-row
-- correlated subqueries.
--
-- CAVEAT: an earlier ad-hoc test of this same technique -- adding the
-- covering index directly to t2 instead of a fresh copy -- measured
-- ~73ms, roughly 2x faster than what's reproducible here. That table
-- had already been scanned repeatedly by exercises 06/06b/the work_mem
-- test beforehand; this t3 is scanned cold. The Index Only Scan's own
-- actual time confirms it: ~100-113ms here vs. ~35ms on the pre-warmed
-- table for the identical 100,000-row scan. The plan SHAPE (Index Only
-- Scan, Heap Fetches: 0, GroupAggregate instead of HashAggregate) is
-- the real, reproducible win; the ~2x absolute number was a
-- warm-cache artifact, not a property of the covering index itself.
-- A production comparison should warm both sides equally before
-- trusting an absolute number.
