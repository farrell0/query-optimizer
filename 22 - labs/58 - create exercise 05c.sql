-- Exercise 05c: keep t3 (exercise 05b's "which entities have at least
-- one active event" table) in sync automatically, instead of
-- rebuilding it from scratch. A trigger on t2 fires on every INSERT/
-- UPDATE/DELETE and adjusts t3 incrementally.
--
-- Adding a row is the easy direction: a new active event means the
-- entity belongs in t3, so just insert it (ON CONFLICT DO NOTHING,
-- since t3.col1 is its own primary key -- idempotent no matter how
-- many active events the entity has).
--
-- Removing a row needs care: you CANNOT just delete from t3 whenever
-- an event stops being active (UPDATE away from 'active', or a
-- DELETE) -- the entity might still have OTHER active events. Only
-- remove it once NO active event remains for that entity at all.
--
-- Run "50 - create exercise 05.sql" and "54 - create exercise 05b
-- .sql" first if you haven't -- this trigger attaches to their t2/t3.

\c my_db48_ex05

CREATE OR REPLACE FUNCTION t2_maintain_t3() RETURNS trigger AS $func$
BEGIN
   IF TG_OP = 'INSERT' THEN
      IF NEW.status = 'active' THEN
         INSERT INTO t3 (col1) VALUES (NEW.col1) ON CONFLICT DO NOTHING;
      END IF;
      RETURN NEW;

   ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.status = 'active' AND OLD.status IS DISTINCT FROM 'active' THEN
         INSERT INTO t3 (col1) VALUES (NEW.col1) ON CONFLICT DO NOTHING;
      ELSIF OLD.status = 'active' AND NEW.status IS DISTINCT FROM 'active' THEN
         IF NOT EXISTS (SELECT 1 FROM t2 WHERE col1 = OLD.col1 AND status = 'active') THEN
            DELETE FROM t3 WHERE col1 = OLD.col1;
         END IF;
      END IF;
      RETURN NEW;

   ELSIF TG_OP = 'DELETE' THEN
      IF OLD.status = 'active' THEN
         IF NOT EXISTS (SELECT 1 FROM t2 WHERE col1 = OLD.col1 AND status = 'active') THEN
            DELETE FROM t3 WHERE col1 = OLD.col1;
         END IF;
      END IF;
      RETURN OLD;
   END IF;
END;
$func$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t2_t3_sync ON t2;

CREATE TRIGGER t2_t3_sync
   AFTER INSERT OR UPDATE OR DELETE ON t2
   FOR EACH ROW EXECUTE FUNCTION t2_maintain_t3();
