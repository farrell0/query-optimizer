-- Exercise 07c: the same query as exercises 07/07b, run with NO hints
-- against t4/t5 (copies of t1/t2 with the secondary indexes reordered
-- to lead with the truly selective column) instead of t1/t2
-- themselves. Run "70 - create exercise 07.sql" and "76 - create
-- exercise 07c.sql" first if you haven't.

\c my_db48_ex07

EXPLAIN (ANALYZE, BUFFERS)
SELECT t4.col1, t4.col2, t5.col3, t3.col1
FROM t4, t5, t3
WHERE t4.col1 = 'LA'
  AND t4.col2 = t5.col1
  AND t5.col3 = 'FLT-00025'
  AND t5.col3 = t3.col1;

-- VERIFIED RESULT: t5's access changes from a Seq Scan + Storage
-- Filter (exercise 07b) to a genuine Index Only Scan seeking directly
-- on col3 (Index Cond, Heap Fetches: 0) -- the case study's fix,
-- reproduced. Execution Time: steady at ~10-12ms after warm-up, vs.
-- exercise 07b's ~37-43ms on the unmodified (single-index) t1/t2 --
-- roughly a 3-4x improvement, a smaller but real win layered on top
-- of an already-fast plan.
--
-- Put all three together (t1 reduced to its one true index, as of
-- this revision -- see "70"'s comment):
--   07  (hints force the 2001 plan shape)         ~385-395ms
--   07b (no hints, original indexes)              ~37-43ms
--   07c (no hints, case study's index reorder)     ~10-12ms
--
-- The ~9-10x gap between 07 and 07b is entirely due to JOIN ORDER and
-- ACCESS PATH CHOICE -- something only a cost-based optimizer with
-- real statistics can get right on its own; hints had to force it
-- back to wrong. The further ~3-4x gap between 07b and 07c is due to
-- INDEX COLUMN ORDER -- a real, independent lever, additive on top of
-- (not a substitute for) good join-order/access-path decisions. The
-- original case study's multi-minute number bundled both effects into
-- one; on this cluster, they cleanly separate into two different
-- causes with two different remedies.
