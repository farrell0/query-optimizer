-- Custom operator wrapping exercise 03b's reverse-index technique, so
-- callers write plain-looking syntax ("does col1 end with this text")
-- instead of manually reversing the search literal and appending '%'
-- themselves every time. Answers the question: can the database
-- server use the reverse index for a standard, unreversed query
-- predicate? Short answer verified below: not for a TRUE unmodified
-- "col1 LIKE '%X'" -- but a custom operator gets you very close.
--
-- Uses t2 from "34 - create exercise 03b.sql" (run that first) --
-- col1_rev is a real, physically STORED generated column with its own
-- index (t2_col1_rev_idx), not a functional/expression index. That
-- matters for everything below.

\c my_db48_ex03

-- ============================================================
-- ATTEMPT 1 (the naive guess) -- operator's left argument is col1,
-- reverse() computed fresh inside the function. VERIFIED NOT TO WORK.
-- ============================================================

CREATE FUNCTION suffix_match_naive(text, text) RETURNS boolean AS $func$
   SELECT reverse($1) LIKE (reverse($2) || '%')
$func$ LANGUAGE sql IMMUTABLE;

CREATE OPERATOR ~~^ (
   LEFTARG = text, RIGHTARG = text, PROCEDURE = suffix_match_naive
);

-- EXPLAIN SELECT * FROM t2 WHERE col1 ~~^ 'GE AK';
--   Seq Scan on t2
--     Storage Filter: (reverse(col1) ~~ 'KA EG%'::text)
--
-- Even though the SQL-language function got inlined (Postgres shows
-- the expanded "reverse(col1) ~~ ..." form, proof the inlining
-- worked), it's still a FRESH expression -- reverse(col1) computed on
-- the fly -- not the same expression as the stored column col1_rev.
-- Index matching for a stored generated column requires the query to
-- reference that column BY NAME; recomputing an equal VALUE via a
-- different expression doesn't count, no matter how "obviously
-- equivalent" the two expressions are to a human. The planner has no
-- general mechanism for recognizing that kind of semantic equivalence.

DROP OPERATOR ~~^ (text, text);
DROP FUNCTION suffix_match_naive(text, text);

-- ============================================================
-- ATTEMPT 2 (the one that actually works) -- operator's left argument
-- is col1_rev itself (the real, already-indexed column). The operator
-- only hides the "reverse the LITERAL and append %" bookkeeping --
-- the caller still names col1_rev, not col1, but writes the SEARCH
-- TEXT in its normal, unreversed form.
-- ============================================================

CREATE FUNCTION reverse_suffix_match(text, text) RETURNS boolean AS $func$
   SELECT $1 LIKE (reverse($2) || '%')
$func$ LANGUAGE sql IMMUTABLE;

CREATE OPERATOR ~~^ (
   LEFTARG = text, RIGHTARG = text, PROCEDURE = reverse_suffix_match
);

-- Compare to exercise 03b's raw form:
--    col1_rev LIKE 'KA EG%'                    -- caller reverses 'GE AK' by hand
-- vs. this operator:
--    col1_rev ~~^ 'GE AK'                      -- caller writes the search text as-is

EXPLAIN (ANALYZE)
SELECT * FROM t2 WHERE col1_rev ~~^ 'GE AK';

-- VERIFIED RESULT:
--   Index Scan using t2_col1_rev_idx on t2 (actual time=22.209..70.513 rows=5000 loops=1)
--     Index Cond: ((col1_rev >= 'KA EG'::text) AND (col1_rev < 'KA EH'::text))
--     Storage Index Filter: (col1_rev ~~ 'KA EG%'::text)
--   Execution Time: 74.450 ms
--
-- Genuinely indexed, and matches exercise 03b's own numbers closely
-- (03b's raw "col1_rev LIKE 'KA EG%'" ran ~42-138ms across repeated
-- runs on this cluster). The operator adds negligible overhead over
-- writing the reversed literal by hand -- because, once inlined, it
-- compiles down to exactly the same plan.
--
-- Bottom line: this is as close to "automatic" as plain SQL gets.
-- The caller still has to know to query col1_rev instead of col1 --
-- that part can't be hidden without something outside SQL's reach
-- (e.g. a C-level planner hook, not achievable here) -- but the
-- "manually reverse my search string" step is gone.
