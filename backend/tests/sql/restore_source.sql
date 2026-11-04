-- SYNTHETIC ONLY: minimal Auth/platform baseline and two application tables.
DO $$ BEGIN
 IF current_database() NOT LIKE 'msu_checkins_rehearsal_%' OR inet_server_addr() <> '127.0.0.1'::inet THEN
  RAISE EXCEPTION 'Synthetic loopback database required';
 END IF;
END $$;
CREATE ROLE postgres NOLOGIN NOSUPERUSER BYPASSRLS;
CREATE ROLE anon NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE authenticated NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE service_role NOLOGIN NOSUPERUSER BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY, email text NOT NULL, encrypted_password text,
                       raw_user_meta_data jsonb NOT NULL DEFAULT '{}');
CREATE TABLE auth.identities(id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id), provider text NOT NULL);
CREATE TABLE auth.schema_migrations(version text PRIMARY KEY);
INSERT INTO auth.schema_migrations VALUES ('synthetic_version_a'),('synthetic_version_b');
CREATE TABLE auth.sessions(id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id));
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA auth TO postgres,authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT CREATE ON SCHEMA public TO postgres;

CREATE SCHEMA storage;
CREATE TABLE storage.buckets(id text PRIMARY KEY);
CREATE TABLE storage.objects(id uuid PRIMARY KEY);
CREATE SCHEMA vault;
CREATE TABLE vault.secrets(id uuid PRIMARY KEY);

INSERT INTO auth.users VALUES
 ('11111111-1111-4111-8111-111111111111','a@example.invalid','synthetic-hash-a','{"full_name":"Synthetic A"}'),
 ('22222222-2222-4222-8222-222222222222','b@example.invalid','synthetic-hash-b','{"full_name":"Synthetic B"}');
INSERT INTO auth.identities VALUES
 ('33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','email'),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','email');
INSERT INTO auth.sessions VALUES ('55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111');

SET ROLE postgres;
CREATE TYPE public."Role" AS ENUM ('PARTICIPANT','PSYCHOLOGIST','SUPERADMIN');
CREATE TYPE public."UserType" AS ENUM ('STUDENT','LECTURER');
CREATE TABLE public.users(
 id uuid PRIMARY KEY REFERENCES auth.users(id), full_name text NOT NULL, email text UNIQUE NOT NULL,
 password_hash text, role public."Role" NOT NULL DEFAULT 'PARTICIPANT',
 is_active boolean NOT NULL DEFAULT true, user_type public."UserType" DEFAULT 'STUDENT'
);
CREATE TABLE public._prisma_migrations(id text PRIMARY KEY, checksum text NOT NULL);
INSERT INTO public.users(id,full_name,email,password_hash) VALUES
 ('11111111-1111-4111-8111-111111111111','Synthetic A','a@example.invalid','synthetic-legacy-a'),
 ('22222222-2222-4222-8222-222222222222','Synthetic B','b@example.invalid',NULL);
INSERT INTO public._prisma_migrations VALUES ('synthetic_1','synthetic_checksum_1'),('synthetic_2','synthetic_checksum_2');

CREATE FUNCTION public.handle_auth_user_created() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.users(id,full_name,email) VALUES(NEW.id,NEW.raw_user_meta_data->>'full_name',NEW.email);
 RETURN NEW;
END $$;
CREATE FUNCTION public.handle_auth_email_changed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.users SET email=NEW.email WHERE id=NEW.id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.handle_auth_user_created(),public.handle_auth_email_changed() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER wellbeing_auth_user_created AFTER INSERT ON auth.users
 FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_created();
CREATE TRIGGER wellbeing_auth_email_changed AFTER UPDATE OF email ON auth.users
 FOR EACH ROW WHEN (OLD.email IS DISTINCT FROM NEW.email) EXECUTE FUNCTION public.handle_auth_email_changed();
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.users FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT(id,full_name,email,role,is_active,user_type) ON public.users TO authenticated;
CREATE POLICY users_read_own_active_profile ON public.users
 FOR SELECT TO authenticated USING((SELECT auth.uid())=id AND is_active=true);
-- Deliberately emulate the legacy ledger issue: staging must restrict this ACL.
GRANT ALL ON public._prisma_migrations TO anon,authenticated,service_role;
RESET ROLE;
