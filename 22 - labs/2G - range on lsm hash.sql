-- Demonstrates that a HASH-sharded LSM primary key does NOT support
-- range queries, even though it's the primary key. Hashing scatters
-- rows by hash(id) across tablets specifically to destroy any
-- meaningful order -- that's what makes it good for even write
-- distribution, and exactly why a '>' predicate on it can't be
-- served as a range/index scan. Compare to "10 - create exercise
-- 01.sql" / "20 - create exercise 02.sql", where the range-scannable
-- column is always the ASC one, never the HASH one.

\c my_db48_ex02

DROP TABLE IF EXISTS hash_range_demo;

CREATE TABLE hash_range_demo (
   id  INT,
   PRIMARY KEY (id HASH)
);

INSERT INTO hash_range_demo (id)
SELECT g FROM generate_series(1, 100000) AS g;

ANALYZE hash_range_demo;

EXPLAIN (ANALYZE)
SELECT * FROM hash_range_demo WHERE id > 50000;
