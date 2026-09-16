-- Exercise 03b: reverse-index technique for suffix-match LIKE queries
-- (col1 LIKE '%suffix', wildcard on the LEFT). A plain ascending index
-- can't help a leading-wildcard pattern -- but reversing both the
-- stored text AND the search literal turns "ends with X" into "starts
-- with reverse(X)", which a normal LSM index CAN serve as a plain
-- prefix range scan.
--
-- Uses its own table (t2), on purpose, so t1 stays untouched as the
-- clean baseline for exercise 03 and the GIN comparison in 03c. t2 is
-- a copy of the SAME data as t1 (same database, my_db48_ex03), so all
-- of exercise 03/03b/03c compare techniques against identical data --
-- run "30 - create exercise 03.sql" first if you haven't.
--
-- col1_rev is GENERATED ALWAYS ... STORED -- reverse() is IMMUTABLE
-- (verified against pg_proc), so this is allowed; see the
-- payment_instruction exploration earlier in this lab for what
-- happens when a generation expression ISN'T immutable.

\c my_db48_ex03

DROP TABLE IF EXISTS t2;

CREATE TABLE t2 (
   id        BIGINT,
   col1      TEXT,
   col1_rev  TEXT GENERATED ALWAYS AS (reverse(col1)) STORED,
   PRIMARY KEY (id HASH)
);

INSERT INTO t2 (id, col1)
SELECT id, col1 FROM t1;

-- Plain ascending LSM index on the reversed text -- ordinary prefix
-- range scan support, nothing exotic needed.
CREATE INDEX t2_col1_rev_idx ON t2 (col1_rev ASC);

ANALYZE t2;



