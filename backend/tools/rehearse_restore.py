"""Native staging-restore test with synthetic local data only; never reads real backups."""

import json
from datetime import datetime, timezone
from uuid import uuid4

from tools.backup_database import BACKEND, file_sha
from tools.rehearse_checkins import isolated_cluster, require
from tools.staging_restore_sql import build_restore_sql, prepare_payload


FACTORY = """
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text NOT NULL,encrypted_password text,
                       raw_user_meta_data jsonb NOT NULL DEFAULT '{}');
CREATE TABLE auth.identities(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES auth.users(id),provider text NOT NULL);
CREATE TABLE auth.schema_migrations(version text PRIMARY KEY);
INSERT INTO auth.schema_migrations VALUES ('synthetic_version_a'),('synthetic_version_b');
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES auth.users(id));
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA auth TO postgres,authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT CREATE ON SCHEMA public TO postgres;
-- Reproduce broad target defaults; restoring source ACL alone must not leak data.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated,service_role;
"""


def main():
    checks = []
    def check(name, condition):
        require(condition, name)
        checks.append(name)
        print("PASS:", name, flush=True)
    with isolated_cluster() as server:
        server.sql((BACKEND / "tests/sql/restore_source.sql").read_text(encoding="utf-8"))
        dump = server.command("pg_dump", ["-w", "--format=custom"])
        require(dump.returncode == 0, "Synthetic source dump failed")
        payload = prepare_payload(dump.stdout)
        check("numeric_toc_selection_and_private_in_memory_render", len(payload["pre"]) > 0 and len(payload["post"]) > 0)
        target = "msu_checkins_rehearsal_restore_" + uuid4().hex
        server.sql(f'CREATE DATABASE "{target}"', database="postgres")
        server.sql(FACTORY, database=target)
        def execute(snapshot):
            script = "SET ROLE postgres;\n" + build_restore_sql(snapshot, expected_database=target)
            return server.command("psql", ["-X","-w","-q","-A","-t","-v","ON_ERROR_STOP=1",
                                           "-v","VERBOSITY=default","-d",target,"-f","-"], input=script.encode())
        broken = {**payload, "post": payload["post"] + "\nSELECT 1/0;\n"}
        result = execute(broken)
        check("late_failure_rolls_back_accounts_and_ddl", result.returncode != 0
              and server.sql("SELECT count(*) FROM auth.users", database=target) == "0"
              and server.sql("SELECT to_regclass('public.users') IS NULL", database=target) == "t")
        server.sql("UPDATE auth.schema_migrations SET version='different' WHERE version='synthetic_version_b'", database=target)
        result = execute(payload)
        check("auth_baseline_difference_rolls_back_without_replacing_managed_history", result.returncode != 0
              and server.sql("SELECT count(*) FROM auth.users", database=target) == "0"
              and server.sql("SELECT count(*) FROM auth.schema_migrations WHERE version='different'", database=target) == "1")
        server.sql("UPDATE auth.schema_migrations SET version='synthetic_version_b' WHERE version='different'", database=target)
        result = execute(payload)
        if result.returncode != 0:
            raise RuntimeError("Synthetic restore failed: " + repr(result.stderr[-1600:]))
        check("single_transaction_restore_confirms_commit", b"MSU_STAGING_RESTORE_COMMIT_OK" in result.stdout)
        check("account_identity_profile_ledger_counts", server.sql(
            "SELECT (SELECT count(*) FROM auth.users)=2 AND (SELECT count(*) FROM auth.identities)=2 "
            "AND (SELECT count(*) FROM public.users)=2 AND (SELECT count(*) FROM public._prisma_migrations)=2", database=target) == "t")
        check("source_sessions_are_not_activated_on_target", server.sql("SELECT count(*) FROM auth.sessions", database=target) == "0")
        check("broad_target_defaults_do_not_leak_hashes_or_ledger", server.sql(
            "SELECT NOT has_column_privilege('authenticated','public.users','password_hash','SELECT') "
            "AND NOT has_table_privilege('anon','public.users','SELECT') "
            "AND NOT has_table_privilege('authenticated','public._prisma_migrations','SELECT') "
            "AND NOT has_table_privilege('service_role','public._prisma_migrations','SELECT')", database=target) == "t")
        check("restored_profile_rls_isolates_users", server.sql("SELECT count(*) FROM public.users", actor="11111111-1111-4111-8111-111111111111", database=target) == "1")
        result = execute(payload)
        check("replay_does_not_overwrite_existing_target", result.returncode != 0
              and server.sql("SELECT count(*) FROM public.users", database=target) == "2")
        server.sql("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES "
                   "('66666666-6666-4666-8666-666666666666','new@example.invalid','{\"full_name\":\"Synthetic New\"}')", database=target)
        check("auth_trigger_restored_after_data_import_without_duplicate_profiles", server.sql(
            "SELECT (SELECT count(*) FROM auth.users)=3 AND (SELECT count(*) FROM public.users)=3", database=target) == "t")
        server.sql("UPDATE auth.users SET email='updated@example.invalid' WHERE id='66666666-6666-4666-8666-666666666666'", database=target)
        check("restored_email_trigger_updates_profile", server.sql(
            "SELECT email='updated@example.invalid' FROM public.users WHERE id='66666666-6666-4666-8666-666666666666'", database=target) == "t")
    report = {"completed_utc":datetime.now(timezone.utc).isoformat(), "checks_passed":checks,
              "source_backup_read":False, "hosted_connections":False,
              "synthetic_cluster_stopped_and_removed":True,
              "restore_sql_module_sha256":file_sha(BACKEND / "tools/staging_restore_sql.py"),
              "real_staging_restore_applied":False}
    (BACKEND / "docs/evidence/staging-restore-native-rehearsal.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("Native application-restore rehearsal passed. No real backup or hosted DB accessed.")


if __name__ == "__main__":
    main()
