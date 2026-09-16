-- Full-text search (lexeme-based GIN), the technique behind Query 6
--
-- Uses its own table (t4), same isolation principle as t2 (03b) and
-- t3 (03c) -- each technique gets a table so none of them can
-- contaminate another's baseline. t4 is a copy of the SAME data as
-- t1/t2/t3 (same database, my_db48_ex03) -- run "30 - create exercise
-- 03.sql" first if you haven't.
--
-- Search phrase: "GOLDEN DRAGON" (from long-tail merchant "GOLDEN
-- DRAGON BUFFET") -- 10,000 of 1,000,000 rows (1%), verified via a
-- direct count. Not the same predicate as 03/03b/03c (those search
-- the CITY/STATE suffix; this searches the MERCHANT name as a
-- multi-word phrase) -- full-text search matches on word boundaries,
-- so it isn't a like-for-like drop-in replacement for a suffix query;
-- it answers a different, word-oriented search need, same as Query 6
-- did in the reference material.

\c my_db48_ex03

DROP TABLE IF EXISTS t4;

CREATE TABLE t4 (
   id    BIGINT,
   col1  TEXT,
   PRIMARY KEY (id HASH)
);

INSERT INTO t4 (id, col1)
SELECT id, col1 FROM t1;

CREATE INDEX t4_col1_lex_idx ON t4 USING gin (to_tsvector('simple', col1));

ANALYZE t4;

-- Mirrors the reference material's own query syntax exactly (escaped
-- space + trailing :* prefix marker on the last word).
EXPLAIN (ANALYZE)
SELECT * FROM t4 WHERE to_tsvector('simple', col1) @@ to_tsquery('simple', 'Golden\ Dragon:*');

-- VERIFIED RESULT -- worth noting a real divergence from the
-- reference material before trusting it blindly on a different
-- cluster/version: to_tsquery('simple', 'Golden\ Dragon:*') resolved
-- HERE to a PHRASE/adjacency query ('golden':* <-> 'dragon':*, "golden
-- immediately followed by dragon"), not the plain AND
-- ('yummy':* & 'donut':*) the reference material's own EXPLAIN output
-- showed for its query. Same escaped-space + :* syntax, different
-- resolved operator -- don't assume to_tsquery's exact parsing matches
-- verbatim across versions/configs; check it (`SELECT
-- to_tsquery(...)` on its own) rather than assume.
--
--   Index Scan using t4_col1_lex_idx on t4 (actual time=15.911..74.592 rows=10000 loops=1)
--     Index Cond: (to_tsvector('simple'::regconfig, col1) @@ '''golden'':* <-> ''dragon'':*'::tsquery)
--   Execution Time: 80.247 ms
--
-- No "Rows Removed by Index Recheck" line at all -- zero false
-- positives. Contrast with exercise 03c's trigram GIN index, which
-- needed 200,000 rows removed by recheck to find 5,000 real matches
-- on a SHORT, space-containing predicate. Word-boundary-aware
-- matching sidesteps exactly the weak-short-trigram problem that made
-- trigram GIN perform so badly there.




