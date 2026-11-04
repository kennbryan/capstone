-- READ ONLY: one SELECT, AFTER approved migration and before live check-in traffic.
-- Metadata checks are NOT substitutes for real two-user RLS tests.
WITH migrations AS (
  SELECT version, applied_at FROM chatbot._backend_migrations ORDER BY version
), objects AS (
  SELECT c.relname, c.relrowsecurity AS rls_enabled
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'chatbot' AND c.relkind = 'r'
), policies AS (
  SELECT policyname, roles, cmd, qual, with_check
  FROM pg_catalog.pg_policies WHERE schemaname = 'chatbot' AND tablename = 'checkins'
), constraints AS (
  SELECT conname, pg_catalog.pg_get_constraintdef(oid) AS definition
  FROM pg_catalog.pg_constraint WHERE conrelid = 'chatbot.checkins'::regclass
), privileges AS (
  SELECT r.role_name,
    pg_catalog.has_schema_privilege(r.role_name, 'chatbot', 'USAGE') AS schema_usage,
    pg_catalog.has_table_privilege(r.role_name, 'chatbot.checkins', 'SELECT') AS can_select,
    pg_catalog.has_column_privilege(r.role_name, 'chatbot.checkins', 'mood', 'INSERT') AS can_insert_mood,
    pg_catalog.has_column_privilege(r.role_name, 'chatbot.checkins', 'mood', 'UPDATE') AS can_update_mood,
    pg_catalog.has_column_privilege(r.role_name, 'chatbot.checkins', 'id', 'INSERT') AS can_insert_id,
    pg_catalog.has_column_privilege(r.role_name, 'chatbot.checkins', 'created_at', 'UPDATE') AS can_change_created_at,
    pg_catalog.has_table_privilege(r.role_name, 'chatbot.checkins', 'DELETE') AS can_delete,
    pg_catalog.has_table_privilege(r.role_name, 'chatbot._backend_migrations', 'SELECT') AS can_read_ledger,
    pg_catalog.has_function_privilege(r.role_name, 'chatbot.prepare_checkin_row()', 'EXECUTE') AS can_call_trigger_function
  FROM (VALUES ('anon'), ('authenticated'), ('service_role')) r(role_name)
), triggers AS (
  SELECT tgname, pg_catalog.pg_get_triggerdef(oid) AS definition
  FROM pg_catalog.pg_trigger
  WHERE tgrelid = 'chatbot.checkins'::regclass AND NOT tgisinternal
)
SELECT '1_migrations' AS section, COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(m)), '[]'::jsonb) AS details FROM migrations m
UNION ALL SELECT '2_objects', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)), '[]'::jsonb) FROM objects o
UNION ALL SELECT '3_policies', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(p)), '[]'::jsonb) FROM policies p
UNION ALL SELECT '4_constraints', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(c)), '[]'::jsonb) FROM constraints c
UNION ALL SELECT '5_privileges', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(p)), '[]'::jsonb) FROM privileges p
UNION ALL SELECT '6_triggers', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(t)), '[]'::jsonb) FROM triggers t
ORDER BY section;
