-- Exercise 05: the "add DISTINCT because the join duplicated rows"
-- pattern. Against the data created by "50 - create exercise 05.sql"
-- (run that file first). Filtering t2 down to 'active' events and
-- joining back to t1 produces 333,333 raw rows (verified) -- one per
-- matching event, not one per entity -- collapsed by DISTINCT back
-- down to the real answer: 100,000 distinct entities.
--
-- Selects a SUBSET of columns from both tables, not everything --
-- t2.status is included deliberately because it's CONSTANT across
-- the result (the WHERE clause already pins it to 'active'); a t2
-- column that varies per event (e.g. t2.id) would make every row
-- unique already and defeat the point of this exercise entirely --
-- DISTINCT would then return all 333,333 rows instead of collapsing
-- to 100,000, since there'd be nothing left to de-duplicate.
--
-- Still includes t1.col10 (the long text column) so DISTINCT still
-- has to compare/hash a wide payload per row, not just narrow keys.

\c my_db48_ex05

EXPLAIN (ANALYZE)
SELECT DISTINCT t1.col1, t1.col4, t1.col9, t1.col10, t2.status
FROM t1
JOIN t2 ON t1.col1 = t2.col1
WHERE t2.status = 'active';
