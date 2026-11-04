-- READ ONLY: one SELECT, so dashboard clients can show all checks in one grid.
-- Run only on the target approved by its owner. No account rows or secret settings.
WITH prerequisites AS (
  SELECT
    pg_catalog.to_regclass('auth.users') IS NOT NULL AS auth_users_present,
    pg_catalog.to_regclass('public.users') IS NOT NULL AS profiles_present,
    pg_catalog.to_regprocedure('auth.uid()') IS NOT NULL AS auth_uid_present,
    EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'chatbot')
      AS chatbot_schema_already_exists
), objects AS (
  SELECT n.nspname AS schema_name, c.relname AS object_name,
         c.relkind AS object_kind, pg_catalog.pg_get_userbyid(c.relowner) AS owner,
         c.relrowsecurity AS rls_enabled
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'chatbot' OR (n.nspname = 'public' AND c.relname = 'users')
  ORDER BY n.nspname, c.relname
), profile_grants AS (
  SELECT column_name,
    CASE WHEN pg_catalog.to_regclass('public.users') IS NOT NULL
              AND EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'authenticated')
      THEN pg_catalog.has_column_privilege('authenticated', 'public.users', column_name, 'SELECT')
      ELSE false END AS authenticated_can_read
  FROM (VALUES ('id'), ('full_name'), ('email'), ('role'), ('is_active')) p(column_name)
), policies AS (
  SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
  FROM pg_catalog.pg_policies
  WHERE schemaname IN ('public', 'chatbot') AND tablename IN ('users', 'checkins')
  ORDER BY schemaname, tablename, policyname
), roles AS (
  SELECT rolname, rolsuper, rolbypassrls, rolinherit
  FROM pg_catalog.pg_roles
  WHERE rolname IN ('anon', 'authenticated', 'service_role', current_user)
), memberships AS (
  -- Includes transitive membership, not only the first parent role.
  SELECT parent.rolname AS inherited_role, member.rolname AS member_role,
         parent.rolsuper, parent.rolbypassrls,
         pg_catalog.pg_has_role(member.oid, parent.oid, 'USAGE') AS privileges_available_without_set_role
  FROM pg_catalog.pg_roles member
  JOIN pg_catalog.pg_roles parent ON parent.oid <> member.oid
    AND pg_catalog.pg_has_role(member.oid, parent.oid, 'MEMBER')
  WHERE member.rolname IN ('anon', 'authenticated', 'service_role')
  ORDER BY member.rolname, parent.rolname
), default_privileges AS (
  SELECT pg_catalog.pg_get_userbyid(d.defaclrole) AS creator_role,
         COALESCE(n.nspname, '(global)') AS schema_name,
         d.defaclobjtype AS object_type, d.defaclacl AS default_acl
  FROM pg_catalog.pg_default_acl d
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = d.defaclnamespace
  WHERE d.defaclnamespace = 0 OR n.nspname = 'chatbot'
)
SELECT '1_prerequisites' AS section, pg_catalog.to_jsonb(p) AS details FROM prerequisites p
UNION ALL SELECT '2_objects', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(o)), '[]'::jsonb) FROM objects o
UNION ALL SELECT '3_profile_grants', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]'::jsonb) FROM profile_grants g
UNION ALL SELECT '4_policies', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(p)), '[]'::jsonb) FROM policies p
UNION ALL SELECT '5_roles', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r)), '[]'::jsonb) FROM roles r
UNION ALL SELECT '6_memberships', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(m)), '[]'::jsonb) FROM memberships m
UNION ALL SELECT '7_default_privileges', COALESCE(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(d)), '[]'::jsonb) FROM default_privileges d
ORDER BY section;
