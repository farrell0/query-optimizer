-- Exercise 02b: SET work_mem per session to see a sort fit entirely in
-- memory (quicksort) instead of spilling to disk. Same data as
-- exercise 02 -- run "20 - create exercise 02.sql" first if you
-- haven't; no new setup needed here, this reuses that t1 as-is.
--
-- work_mem here is set via SET, so it only affects this session/
-- connection -- a tuning knob, not a schema or index change. 16MB is
-- comfortably above the ~13MB this particular 100,000-row sort needs.

\c my_db48_ex02

SET work_mem = '16MB';

EXPLAIN (ANALYZE)
select *
from t1
order by
      col2;


