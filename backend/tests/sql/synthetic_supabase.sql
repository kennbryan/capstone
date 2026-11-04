-- SYNTHETIC FIXTURE ONLY. Never run this against hosted Supabase or user data.
DO $$
BEGIN
  IF current_database() NOT LIKE 'msu_checkins_rehearsal_%'
     OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
    RAISE EXCEPTION 'Only the marked loopback synthetic rehearsal is allowed';
  END IF;
END;
$$;

CREATE ROLE anon NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE authenticated NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE service_role NOLOGIN NOSUPERUSER BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY, email text NOT NULL);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;

CREATE TYPE public."Role" AS ENUM ('PARTICIPANT', 'PSYCHOLOGIST', 'SUPERADMIN');
CREATE TABLE public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  full_name text NOT NULL,
  email text NOT NULL,
  role public."Role" NOT NULL DEFAULT 'PARTICIPANT',
  is_active boolean NOT NULL DEFAULT true
);
REVOKE ALL ON public.users FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT (id, full_name, email, role, is_active) ON public.users TO authenticated;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_read_own_active_profile ON public.users
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = id AND is_active = true);

INSERT INTO auth.users (id, email) VALUES
 ('11111111-1111-4111-8111-111111111111', 'synthetic-a@example.invalid'),
 ('22222222-2222-4222-8222-222222222222', 'synthetic-b@example.invalid'),
 ('33333333-3333-4333-8333-333333333333', 'synthetic-inactive@example.invalid'),
 ('44444444-4444-4444-8444-444444444444', 'synthetic-psychologist@example.invalid'),
 ('55555555-5555-4555-8555-555555555555', 'synthetic-admin@example.invalid');
INSERT INTO public.users (id, full_name, email, role, is_active)
SELECT id, 'Synthetic fixture', email,
       CASE WHEN email LIKE 'synthetic-psychologist%' THEN 'PSYCHOLOGIST'::public."Role"
            WHEN email LIKE 'synthetic-admin%' THEN 'SUPERADMIN'::public."Role"
            ELSE 'PARTICIPANT'::public."Role" END,
       email NOT LIKE 'synthetic-inactive%'
FROM auth.users;
