-- Exercise 03 setup: 1,000,000 rows of realistic bank-transaction-style
-- merchant description text, modeled on the reference material at
-- "15 - Clients/15 - US Bank/22 - Query 03" (enriched transaction
-- description LIKE/GIN search). Intentionally skewed like real
-- transaction data: 5 major merchants cover 75% of rows, a long tail
-- of 25 smaller merchants covers the rest -- so different substrings
-- have very different selectivity, matching the reference material's
-- own lesson: common substrings match millions of candidate rows that
-- must be rechecked (slow); rare ones match almost nothing (fast).
--
-- No supporting index on col1 yet -- this is the baseline, run in its
-- own database (my_db48_ex03), following the my_db48_ex01/ex02 naming
-- convention from exercises 01 and 02.

SELECT 'CREATE DATABASE my_db48_ex03'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'my_db48_ex03')
\gexec

\c my_db48_ex03

DROP TABLE IF EXISTS t1;

-- Explicit HASH primary key -- see "10 - create exercise 01.sql" for
-- why (id is a monotonically increasing sequence; hashing avoids a
-- moving-sequential-hotspot on writes).
CREATE TABLE t1 (
   id    BIGINT,
   col1  TEXT,
   PRIMARY KEY (id HASH)
);

-- col1: "<merchant> #<5-digit store number> <city> <state>", e.g.
-- "STARBUCKS COFFEE #04521 SEATTLE WA" -- deliberately mirrors the
-- reference material's "Yummy Donut"-style enriched description shape.
--
-- Merchant distribution (out of every 1,000 rows):
--    150 WALMART SUPERCENTER   (top merchant, very common substrings)
--    150 STARBUCKS COFFEE
--    150 AMAZON.COM
--    150 TARGET STORE
--    150 SHELL OIL
--    250 split across 25 long-tail small businesses (~10 rows/1,000
--        each = rare substrings, low selectivity cost)
--
-- City/state is ALSO deliberately skewed (not uniform) -- this is what
-- the suffix (col1 LIKE '%...') examples key off of, so common-suffix
-- vs. rare-suffix selectivity is a real, visible dataset property, not
-- just a merchant-name-substring property:
--    400 SEATTLE WA     (dominant -- suffix "LE WA")
--    300 DALLAS TX
--    150 CHICAGO IL
--    100 HOUSTON TX
--     30 PHOENIX AZ
--     15 DENVER CO
--      5 ANCHORAGE AK   (rare -- suffix "GE AK")
INSERT INTO t1 (id, col1)
SELECT
   g,
   (CASE
      WHEN g % 1000 < 150 THEN 'WALMART SUPERCENTER'
      WHEN g % 1000 < 300 THEN 'STARBUCKS COFFEE'
      WHEN g % 1000 < 450 THEN 'AMAZON.COM'
      WHEN g % 1000 < 600 THEN 'TARGET STORE'
      WHEN g % 1000 < 750 THEN 'SHELL OIL'
      ELSE (ARRAY[
         'ACME HARDWARE','MAIN STREET DINER','RIVERSIDE AUTO REPAIR','BLUE SKY BAKERY','NORTHSIDE PET CLINIC',
         'GOLDEN DRAGON BUFFET','LAKEVIEW DRY CLEANERS','SUMMIT COFFEE ROASTERS','IRONWOOD FITNESS CENTER','PEACHTREE FLORIST',
         'CEDAR PARK BARBERSHOP','MOONLIGHT DINER','HARBOR VIEW SEAFOOD','GRANITE STATE HARDWARE','WILLOW CREEK BAKERY',
         'STONEBRIDGE VETERINARY','MAPLE LEAF DONUTS','CRESCENT MOON BOOKS','TWIN OAKS GARAGE','SILVER FOX SALON',
         'PRAIRIE WIND FARM MARKET','COBBLESTONE CAFE','EVERGREEN NURSERY','BRASS LANTERN PUB','QUARTZ VALLEY GYM'
      ])[((g % 1000 - 750) / 10) + 1]
    END)
   || ' #' || lpad(((g % 9999) + 1)::text, 5, '0')
   || ' ' || (CASE
      WHEN g % 1000 < 400 THEN 'SEATTLE WA'
      WHEN g % 1000 < 700 THEN 'DALLAS TX'
      WHEN g % 1000 < 850 THEN 'CHICAGO IL'
      WHEN g % 1000 < 950 THEN 'HOUSTON TX'
      WHEN g % 1000 < 980 THEN 'PHOENIX AZ'
      WHEN g % 1000 < 995 THEN 'DENVER CO'
      ELSE 'ANCHORAGE AK'
   END)
FROM generate_series(1, 1000000) AS g;

ANALYZE t1;


