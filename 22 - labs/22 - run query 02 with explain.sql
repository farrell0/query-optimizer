-- Exercise 02: EXPLAIN for an OR across two different columns, both
-- indexed, against the data created by "20 - create exercise 02.sql"
-- (run that file first). Expect a BitmapOr: one Bitmap Index Scan per
-- column, combined, then a single fetch from the table.

\c my_db48_ex02

EXPLAIN (ANALYZE)
select *
from t1
where
      col1 = 10
or
      col2 = 20;


