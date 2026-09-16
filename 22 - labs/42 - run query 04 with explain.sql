-- Exercise 04: baseline EXPLAIN for a simple two-table LEFT OUTER
-- JOIN, against the data created by "40 - create exercise 04.sql"
-- (run that file first). t1 is the OUTER (preserved) table; t2 is
-- the INNER (joined-to) table -- 90,000 of t1's 100,000 rows have no
-- match in t2, so this genuinely exercises outer-join NULL-extension,
-- not something an inner join would answer the same way.

\c my_db48_ex04

EXPLAIN (ANALYZE)
SELECT *
FROM t1
LEFT OUTER JOIN t2 ON t1.col1 = t2.col1;

-- VERIFIED RESULT: planner naturally picks Hash Left Join, with t2
-- (the smaller, non-preserved side) built into the in-memory hash
-- table FIRST, then t1 (the preserved side) streamed through as the
-- probe -- so "read the inner table first" already happens by
-- default here, no hint needed.
--
-- FOLLOW-UP QUESTION TESTED: can a hint force a Nested Loop plan to
-- drive from t2 (inner) instead of t1 (outer/preserved)? Tested both
-- ways:
--   1. SET enable_hashjoin = off; SET enable_mergejoin = off;
--      -> YB Batched Nested Loop Left Join, t1 as the outer/driving
--         side (Seq Scan), t2 probed via Index Scan. t1 driving is
--         NOT a cost choice here -- it's the only valid option.
--   2. Same, plus a pg_hint_plan Leading((t2 t1)) hint explicitly
--      requesting t2 first -- produced the BYTE-FOR-BYTE IDENTICAL
--      plan. The hint had no alternative to select from.
--
-- Why: a Nested Loop implementing a LEFT JOIN must iterate every row
-- of the PRESERVED side exactly once (to correctly null-extend
-- unmatched rows) -- that only works if the preserved side (t1) is
-- the outer/driving loop. Driving from t2 instead would only visit
-- t2's rows, never surfacing t1's 90,000 unmatched rows at all --
-- not an alternate strategy for the same query, a different (wrong)
-- answer. This is why NO hint can force it: pg_hint_plan's Leading()
-- only reorders among plans the optimizer would consider valid in
-- the first place: it constrains the search space, it doesn't
-- override join semantics.


