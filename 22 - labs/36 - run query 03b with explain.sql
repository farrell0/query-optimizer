-- Exercise 03b: the same suffix search as exercise 03 ("ends with
-- ANCHORAGE AK"), rewritten to use the reverse-index on t2. Original:
-- col1 LIKE '%GE AK'. Rewritten: col1_rev LIKE 'KA EG%' (reverse('GE
-- AK') = 'KA EG', verified directly) -- an ordinary prefix match,
-- fully sargable against t2_col1_rev_idx.
--
-- Note this is an EXACT rewrite, not an approximate one -- unlike a
-- GIN trigram index (exercise 03c), there's no false-positive
-- candidate set here to recheck. reverse() is a bijection, so
-- "reversed text starts with reverse(X)" and "original text ends with
-- X" are exactly the same set of rows.

\c my_db48_ex03

-- SELECT * (not just id/col1) to keep this a fair apples-to-apples
-- comparison against exercise 03's SELECT * -- t2 has the extra
-- col1_rev column, so the row width isn't identical to t1, but the
-- comparison is still fair on how much WORK the planner has to do.
EXPLAIN (ANALYZE)
SELECT * FROM t2 WHERE col1_rev LIKE 'KA EG%';


