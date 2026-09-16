-- Exercise 06b: instead of paying for a COUNT and a SUM correlated
-- subquery per t1 row (exercise 06), aggregate t2 ONCE via GROUP BY
-- -- one pass over all of t2, producing one row per entity -- then
-- join that pre-aggregated result back to t1 and apply the same
-- filter. Same logical answer as exercise 06, computed via a single
-- aggregation instead of 10,000 individual probes.
--
-- Run "60 - create exercise 06.sql" first if you haven't -- reuses
-- t1/t2 from there.

\c my_db48_ex06

EXPLAIN (ANALYZE, BUFFERS)
WITH agg AS (
    SELECT col2 AS entity_id, COUNT(*) AS row_count, SUM(col3) AS total_val
    FROM t2
    GROUP BY col2
)
SELECT t1.col1, t1.col2, agg.row_count, agg.total_val
FROM t1
JOIN agg ON agg.entity_id = t1.col1
WHERE t1.col2 = 'West';

-- VERIFIED RESULT: one Seq Scan over all of t2 feeding a single
-- HashAggregate (20,000 groups, one per t1 entity), Hash Joined to
-- the 5,000 filtered t1 rows. No per-row subplans, no repeated index
-- probes. Execution Time: ~166ms -- roughly 100x faster than exercise
-- 06's 10,000-probe correlated-subquery version, computing the exact
-- same answer.
--
-- FURTHER TUNING TESTED: the HashAggregate here spills to disk at the
-- default work_mem (Batches: 5, Disk Usage: 696kB) -- raising work_mem
-- to 64MB keeps it in memory (Batches: 1) and trims this to ~137ms.
-- Bigger win: see "68 - run query 06c with explain.sql", which adds a
-- COVERING index so the aggregation is satisfied entirely by an Index
-- Only Scan (no HashAggregate, no work_mem exposure at all).
