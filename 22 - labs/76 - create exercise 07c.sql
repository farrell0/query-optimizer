-- Exercise 07c setup: the case study's actual fix -- lead the
-- secondary index with the truly selective column instead of the
-- join/near-constant column:
--
--   t1 (col1, col2)       -> t4 (col2, col1)
--   t2 (col1, col2, col3) -> t5 (col3, col2, col1)
--
-- Uses its OWN copies (t4, t5) instead of altering t1/t2 -- so
-- exercises 07 and 07b stay exactly as documented, independent of
-- this one, no matter what order all three are run in. t3 is shared/
-- read-only either way -- "table c was fine" in the original case
-- study, and it isn't being re-indexed.
--
-- Run "70 - create exercise 07.sql" first if you haven't (this reads
-- t1/t2 from there to seed t4/t5, and reuses t3 directly).

\c my_db48_ex07

DROP TABLE IF EXISTS t5;
DROP TABLE IF EXISTS t4;

CREATE TABLE t4 (
   col1  TEXT,
   col2  TEXT,
   col3  INT,
   col4  TEXT,
   col5  TEXT,
   col6  TIMESTAMP,
   col7  NUMERIC(10,2),
   col8  TEXT,
   PRIMARY KEY (col2 HASH, col1 ASC)
);
INSERT INTO t4 (col1, col2, col3, col4, col5, col6, col7, col8)
   SELECT col1, col2, col3, col4, col5, col6, col7, col8 FROM t1;

CREATE TABLE t5 (
   id    BIGINT,
   col1  TEXT,
   col2  SMALLINT,
   col3  TEXT,
   PRIMARY KEY (id HASH)
);
INSERT INTO t5 (id, col1, col2, col3) SELECT id, col1, col2, col3 FROM t2;
CREATE INDEX idx_t5_col3_col2_col1 ON t5 (col3 HASH, col2 ASC, col1 ASC);

ANALYZE t4;
ANALYZE t5;
