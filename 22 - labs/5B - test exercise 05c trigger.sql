-- Exercise 05c test: exercises all the cases the trigger from "58 -
-- create exercise 05c.sql" has to get right. Uses entity 999999,
-- deliberately outside t1's real 1..100,000 range, so this never
-- disturbs the actual exercise 05/05b data -- t2.col1 has no foreign
-- key constraint to t1, so this is a safe, isolated scratch entity.
--
-- Run "58 - create exercise 05c.sql" first if you haven't.

\c my_db48_ex05

SELECT 'before insert' AS step, count(*) FROM t3 WHERE col1 = 999999;

-- add two active events for the same entity
INSERT INTO t2 (id, col1, status) VALUES (9999001, 999999, 'active');
INSERT INTO t2 (id, col1, status) VALUES (9999002, 999999, 'active');
SELECT 'after 2 active inserts (expect 1)' AS step, count(*) FROM t3 WHERE col1 = 999999;

-- remove ONE of the two active events -- should still be in t3
DELETE FROM t2 WHERE id = 9999001;
SELECT 'after deleting 1 of 2 active (expect 1)' AS step, count(*) FROM t3 WHERE col1 = 999999;

-- remove the LAST active event -- should now disappear from t3
DELETE FROM t2 WHERE id = 9999002;
SELECT 'after deleting the last active (expect 0)' AS step, count(*) FROM t3 WHERE col1 = 999999;

-- exercise the UPDATE-away-from-active and UPDATE-back-to-active paths too
INSERT INTO t2 (id, col1, status) VALUES (9999003, 999999, 'active');
SELECT 'after insert (expect 1)' AS step, count(*) FROM t3 WHERE col1 = 999999;

UPDATE t2 SET status = 'inactive' WHERE id = 9999003;
SELECT 'after update to inactive (expect 0)' AS step, count(*) FROM t3 WHERE col1 = 999999;

UPDATE t2 SET status = 'active' WHERE id = 9999003;
SELECT 'after update back to active (expect 1)' AS step, count(*) FROM t3 WHERE col1 = 999999;

-- clean up the scratch entity -- the trigger removes it from t3 too,
-- no manual t3 cleanup needed
DELETE FROM t2 WHERE id = 9999003;
SELECT 'after final cleanup (expect 0 in both)' AS step,
       (SELECT count(*) FROM t2 WHERE col1 = 999999) AS t2_count,
       (SELECT count(*) FROM t3 WHERE col1 = 999999) AS t3_count;
