-- Exercise 03c: the exact same query and data as exercise 03's
-- baseline (col1 LIKE '%GE AK', the rare 0.5%-selectivity suffix),
-- now against t3 -- a copy of t1's data with the pg_trgm GIN index
-- from "38 - create exercise 03c.sql" added. Deliberately a
-- DIFFERENT table than exercise 03's t1, so this index can't leak
-- into (and silently change) the no-index baseline.
--
-- Unlike the reverse-index technique (03b), a trigram GIN index is
-- APPROXIMATE: it returns every row containing the right trigrams as a
-- CANDIDATE, then rechecks each candidate against the real LIKE
-- pattern -- this is exactly the "Rows Removed by Index Recheck"
-- mechanism the reference material's whole analysis is about.
--
-- VERIFIED RESULT, and it's a genuine surprise worth understanding:
-- this GIN-indexed run took ~4,189ms with 200,000 rows removed by
-- recheck to find 5,000 real matches -- SLOWER than exercise 03's
-- no-index Seq Scan (257ms), and ~100x slower than 03b's reverse
-- index (42.5ms).
--
-- Why: run `SELECT show_trgm('GE AK')` -- pg_trgm treats "GE" and
-- "AK" as two separate SHORT WORDS (both under 3 characters) and pads
-- each independently: {"  g"," ge","ge ", "  a"," ak","ak "}. These
-- padded 2-letter-word trigrams aren't specific to "a word ending in
-- GE immediately followed by AK" -- they match ANY row containing a
-- standalone word trigram-compatible with "GE" (e.g. the "GE" inside
-- "TARGET STORE" or "TWIN OAKS GARAGE") and, independently, ANY row
-- with something trigram-compatible with "AK" (e.g. "LAKEVIEW DRY
-- CLEANERS"), even when they're nowhere near each other in the text.
-- Short words produce weak, unselective trigrams -- GIN doesn't know
-- the overall 5-character PATTERN is rare; it only knows individual
-- trigram frequency, and short-word trigrams here are common.

\c my_db48_ex03

EXPLAIN (ANALYZE)
SELECT * FROM t3 WHERE col1 LIKE '%GE AK';


