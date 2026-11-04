-- READ ONLY. Run in the NEW staging project's SQL Editor.
-- Returns counts and object metadata only, never email, UUID, password or row contents.
-- SQL Editor connection identity must be checked in the dashboard URL separately.
WITH public_application_tables AS (
  SELECT c.relname AS table_name
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
    AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_depend d
      WHERE d.classid = 'pg_catalog.pg_class'::regclass
        AND d.objid = c.oid AND d.deptype = 'e'
        AND d.refclassid = 'pg_catalog.pg_extension'::regclass
    )
), state AS (
  SELECT
    pg_catalog.current_database() AS database_name,
    pg_catalog.current_setting('server_version') AS server_version,
    pg_catalog.current_setting('server_version_num')::integer AS server_version_num,
    (SELECT count(*) FROM auth.users) AS auth_user_count,
    pg_catalog.to_regclass('public.users') IS NOT NULL AS website_profile_table_present,
    pg_catalog.to_regclass('public._prisma_migrations') IS NOT NULL AS website_ledger_present,
    EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'chatbot') AS chatbot_schema_present,
    (SELECT count(*) FROM public_application_tables) AS public_application_table_count
)
SELECT pg_catalog.jsonb_build_object(
  'database', s.database_name,
  'server_version', s.server_version,
  'server_version_num', s.server_version_num,
  'auth_user_count', s.auth_user_count,
  'website_profile_table_present', s.website_profile_table_present,
  'website_ledger_present', s.website_ledger_present,
  'chatbot_schema_present', s.chatbot_schema_present,
  'public_application_table_count', s.public_application_table_count,
  'public_application_tables', COALESCE(
    (SELECT pg_catalog.jsonb_agg(table_name ORDER BY table_name) FROM public_application_tables), '[]'::jsonb),
  'extensions', COALESCE((
    SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'name', e.extname, 'version', e.extversion, 'schema', n.nspname) ORDER BY e.extname)
    FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
  ), '[]'::jsonb),
  'initial_empty_target_candidate', s.database_name = 'postgres'
    AND s.auth_user_count = 0 AND s.public_application_table_count = 0
    AND NOT s.website_profile_table_present AND NOT s.website_ledger_present
    AND NOT s.chatbot_schema_present
) AS staging_preflight
FROM state s;
