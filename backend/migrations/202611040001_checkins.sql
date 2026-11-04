-- REVIEW REQUIRED. Not applied by app startup or tests.
-- New chatbot schema only. If the schema already exists, STOP and reconcile ownership.
-- Do not edit this migration after it is applied; add a subsequent migration instead.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
SELECT pg_catalog.pg_advisory_xact_lock(20261104, 1);

DO $$
BEGIN
  IF pg_catalog.to_regclass('auth.users') IS NULL
     OR pg_catalog.to_regclass('public.users') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION 'Required shared Auth/profile objects are missing; no changes applied';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'chatbot') THEN
    RAISE EXCEPTION 'chatbot schema already exists; review its ownership/history, do not overwrite';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles
    WHERE rolname = 'authenticated' AND (rolsuper OR rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'authenticated must not be superuser or BYPASSRLS';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.users'::regclass AND relrowsecurity
  ) THEN
    RAISE EXCEPTION 'Profile RLS must be enabled before this migration';
  END IF;
  IF NOT pg_catalog.has_schema_privilege('authenticated', 'public', 'USAGE')
     OR NOT pg_catalog.has_column_privilege('authenticated', 'public.users', 'id', 'SELECT')
     OR NOT pg_catalog.has_column_privilege('authenticated', 'public.users', 'role', 'SELECT')
     OR NOT pg_catalog.has_column_privilege('authenticated', 'public.users', 'is_active', 'SELECT') THEN
    RAISE EXCEPTION 'Existing authenticated profile-read privileges are required';
  END IF;
END;
$$;

CREATE SCHEMA chatbot;
REVOKE ALL ON SCHEMA chatbot FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA chatbot TO authenticated;

CREATE TABLE chatbot._backend_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
REVOKE ALL ON chatbot._backend_migrations FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE chatbot._backend_migrations ENABLE ROW LEVEL SECURITY;

CREATE TABLE chatbot.checkins (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  date date NOT NULL CHECK (date BETWEEN DATE '0001-01-01' AND DATE '9999-12-31'),
  mood smallint NOT NULL CHECK (mood BETWEEN 1 AND 5),
  note text CHECK (note IS NULL OR pg_catalog.char_length(note) <= 200),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
  CONSTRAINT checkins_user_date_key UNIQUE (user_id, date)
);

CREATE FUNCTION chatbot.prepare_checkin_row()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.date IS DISTINCT FROM OLD.date
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Check-in identity, owner, date and creation time are immutable'
        USING ERRCODE = '23514';
    END IF;
  ELSE
    NEW.created_at := pg_catalog.clock_timestamp();
  END IF;
  NEW.updated_at := pg_catalog.clock_timestamp();
  NEW.note := NULLIF(pg_catalog.btrim(NEW.note), '');
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION chatbot.prepare_checkin_row() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER checkins_prepare_row
  BEFORE INSERT OR UPDATE ON chatbot.checkins
  FOR EACH ROW EXECUTE FUNCTION chatbot.prepare_checkin_row();

-- Explicit per-object revocation also removes inherited creator default ACL grants.
-- Role memberships/BYPASSRLS still require the separate privilege preflight review.
REVOKE ALL ON chatbot.checkins FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON chatbot.checkins TO authenticated;
GRANT INSERT (user_id, date, mood, note) ON chatbot.checkins TO authenticated;
-- PostgREST merge-duplicates assigns each payload column. The trigger above
-- prevents changing owner/date while allowing ON CONFLICT to assign the same values.
GRANT UPDATE (user_id, date, mood, note) ON chatbot.checkins TO authenticated;
ALTER TABLE chatbot.checkins ENABLE ROW LEVEL SECURITY;

CREATE POLICY checkins_read_own_active_participant ON chatbot.checkins
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.users p WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true AND p.role::text = 'PARTICIPANT'
    )
  );

CREATE POLICY checkins_insert_own_active_participant ON chatbot.checkins
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.users p WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true AND p.role::text = 'PARTICIPANT'
    )
  );

CREATE POLICY checkins_update_own_active_participant ON chatbot.checkins
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.users p WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true AND p.role::text = 'PARTICIPANT'
    )
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.users p WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true AND p.role::text = 'PARTICIPANT'
    )
  );

COMMENT ON TABLE chatbot.checkins IS
  'Companion daily check-ins. Private notes must not be logged or sent to AI without approved consent.';
COMMENT ON TABLE chatbot._backend_migrations IS
  'Companion-only ledger; never share public._prisma_migrations.';

INSERT INTO chatbot._backend_migrations(version) VALUES ('202611040001_checkins');
NOTIFY pgrst, 'reload schema';
COMMIT;
