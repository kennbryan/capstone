"""Exercise the real check-in migration/RLS on an exclusive synthetic local PG17 cluster.

Never reads .env, real backups, private keys or external database credentials.
This is not a hosted Supabase restore test or PostgREST/JWT integration test.
"""

from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import datetime, timezone
import json
from pathlib import Path, PurePosixPath
import shutil
import socket
import subprocess
import time
from uuid import uuid4
import zipfile

from tools.backup_database import BACKEND, TOOLS, clean_environment, file_sha, verified_tools

USERS = [f"{n}" * 8 + "-" + f"{n}" * 4 + "-4" + f"{n}" * 3 + "-8" + f"{n}" * 3 + "-" + f"{n}" * 12 for n in range(1, 6)]
DAY = "2000-01-01"
FLAGS = getattr(subprocess, "CREATE_NO_WINDOW", 0)
MIGRATION = BACKEND / "migrations/202611040001_checkins.sql"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def prepare_server():
    manifest = verified_tools()
    package = TOOLS / "postgresql-17.11.zip"
    require(file_sha(package) == manifest["package_sha256"]["postgresql"], "Portable package changed")
    server_exes = {"pgsql/bin/initdb.exe", "pgsql/bin/postgres.exe", "pgsql/bin/pg_ctl.exe"}
    with zipfile.ZipFile(package) as archive:
        for item in archive.infolist():
            path = PurePosixPath(item.filename)
            selected = (item.filename in server_exes or item.filename.startswith("pgsql/share/")
                        or (path.parent.as_posix() == "pgsql/lib" and path.suffix == ".dll"))
            if not selected or item.is_dir():
                continue
            target = (TOOLS / item.filename).resolve()
            require(target.is_relative_to(TOOLS.resolve()), "Invalid portable archive member")
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)


class LocalPostgres:
    def __init__(self, run, port, database):
        self.run, self.port, self.database = run, port, database
        self.data = run / "data"
        self.env = {**clean_environment(), "PGHOST": "127.0.0.1", "PGPORT": str(port),
                    "PGDATABASE": database, "PGUSER": "synthetic_owner", "PGSSLMODE": "disable",
                    "PGCONNECT_TIMEOUT": "2"}
        self.process = None
        self.log = None
        self.stopped = True

    def command(self, name, args, **kwargs):
        return subprocess.run([str(TOOLS / "pgsql/bin" / (name + ".exe")), *args],
                              env=self.env, capture_output=True, creationflags=FLAGS,
                              timeout=kwargs.pop("timeout", 60), **kwargs)

    def sql(self, statement, *, actor=None, role="authenticated", error=None, database=None):
        prefix = ""
        if actor is not None:
            require(actor in USERS and role == "authenticated", "Invalid synthetic identity")
            prefix = f"SET ROLE authenticated; SET request.jwt.claim.sub = '{actor}'; "
        elif role != "authenticated":
            require(role in ("anon", "service_role"), "Invalid synthetic role")
            prefix = f"SET ROLE {role}; "
        result = self.command("psql", ["-X", "-w", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1",
                                       "-v", "VERBOSITY=sqlstate", "-d", database or self.database,
                                       "-c", prefix + statement])
        if error:
            require(result.returncode != 0 and any(code.encode() in result.stderr for code in error),
                    "Expected synthetic rejection did not occur: " + repr(result.stderr[:400]))
            return None
        require(result.returncode == 0, "Synthetic SQL failed: " + repr(result.stderr[:600]))
        return result.stdout.decode("utf-8").strip()

    def start(self):
        result = self.command("initdb", ["-D", str(self.data), "-U", "synthetic_owner",
                                         "--auth=trust", "--locale=C", "--encoding=UTF8", "--no-sync"], timeout=120)
        require(result.returncode == 0, "Synthetic initdb failed: " + repr(result.stderr[-1000:]))
        self.log = (self.run / "server.log").open("wb")
        self.process = subprocess.Popen(
            [str(TOOLS / "pgsql/bin/postgres.exe"), "-D", str(self.data), "-h", "127.0.0.1",
             "-p", str(self.port), "-c", "shared_buffers=16MB", "-c", "max_connections=12",
             "-c", "fsync=off", "-c", "lc_messages=C"],
            stdout=self.log, stderr=self.log, env=self.env, creationflags=FLAGS,
        )
        self.stopped = False
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline and self.process.poll() is None:
            result = self.command("psql", ["-X", "-w", "-A", "-t", "-d", "postgres", "-c", "SELECT 1"], timeout=5)
            if result.returncode == 0:
                break
            time.sleep(0.2)
        else:
            raise RuntimeError("Synthetic server did not start; inspect synthetic server.log")
        actual = self.sql("SHOW data_directory", database="postgres")
        require(Path(actual).resolve() == self.data.resolve(), "Connected to wrong data directory")
        self.sql(f'CREATE DATABASE "{self.database}"', database="postgres")

    def stop(self):
        if self.process is not None and self.process.poll() is None:
            # Only the exclusive newly created data directory belongs to this process.
            result = self.command("pg_ctl", ["-D", str(self.data), "-m", "fast", "-w", "-t", "20", "stop"], timeout=30)
            require(result.returncode == 0, "Synthetic cluster could not stop; preserve its directory")
            self.process.wait(timeout=10)
        self.stopped = True
        if self.log:
            self.log.close()


@contextmanager
def isolated_cluster():
    prepare_server()
    root = (TOOLS / "rehearsals").resolve()
    root.mkdir(exist_ok=True)
    token = uuid4().hex
    run = root / token
    run.mkdir()
    (run / "SYNTHETIC_ONLY").write_text(token, encoding="ascii")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    server = LocalPostgres(run, port, "msu_checkins_rehearsal_" + token)
    try:
        server.start()
        yield server
    finally:
        server.stop()
        # Verified absolute target and ownership marker before recursive cleanup.
        resolved = run.resolve()
        if server.stopped and resolved.is_relative_to(root) and resolved != root:
            require((resolved / "SYNTHETIC_ONLY").read_text(encoding="ascii") == token, "Cleanup marker mismatch")
            shutil.rmtree(resolved)


def insert(user, mood=3, note="NULL", day=DAY):
    return ("INSERT INTO chatbot.checkins(user_id,date,mood,note) "
            f"VALUES ('{user}','{day}',{mood},{note}) "
            "ON CONFLICT (user_id,date) DO UPDATE SET user_id=excluded.user_id,date=excluded.date,"
            "mood=excluded.mood,note=excluded.note RETURNING id")


def run_checks(server):
    passed = []
    def check(name, condition=True):
        require(condition, name)
        passed.append(name)
        print("PASS:", name, flush=True)
    staging_query = (BACKEND / "sql/staging_restore_preflight.sql").read_text(encoding="utf-8-sig")
    # A temporary empty auth stub exercises the metadata query before the real fixture.
    # This directory/DB is exclusively synthetic and guarded by isolated_cluster().
    server.sql("CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY)")
    empty_state = json.loads(server.sql(staging_query))
    check("staging_preflight_executes_on_empty_synthetic_target",
          empty_state["auth_user_count"] == 0 and empty_state["public_application_table_count"] == 0)
    server.sql("DROP TABLE auth.users; DROP SCHEMA auth")
    fixture = (BACKEND / "tests/sql/synthetic_supabase.sql").read_text(encoding="utf-8-sig")
    server.sql(fixture)
    occupied_state = json.loads(server.sql(staging_query))
    check("staging_preflight_identifies_existing_application_data",
          occupied_state["auth_user_count"] == 5 and occupied_state["website_profile_table_present"]
          and not occupied_state["initial_empty_target_candidate"])
    profile_before = server.sql("SELECT json_build_object('count',(SELECT count(*) FROM public.users),"
                                "'acl',(SELECT relacl FROM pg_class WHERE oid='public.users'::regclass),"
                                "'policy',(SELECT qual FROM pg_policies WHERE tablename='users'))")
    server.sql(MIGRATION.read_text(encoding="utf-8-sig"))
    check("actual_migration_commits_on_fresh_synthetic_database")
    check("separate_ledger", server.sql("SELECT count(*) FROM chatbot._backend_migrations") == "1")
    for name in ("checkins_preflight.sql", "checkins_verify.sql"):
        # Exercise the exact operator queries on PostgreSQL, not a string-based test.
        server.sql((BACKEND / "sql" / name).read_text(encoding="utf-8-sig"))
        check("operator_query_" + name)
    a, b, inactive, psychologist, admin = USERS
    first = server.sql(insert(a, 4, "'synthetic-a'"), actor=a)
    server.sql(insert(b, 5, "'synthetic-b'"), actor=b)
    check("own_insert_and_read", server.sql("SELECT count(*) FROM chatbot.checkins", actor=a) == "1")
    check("same_date_two_accounts", server.sql("SELECT count(*) FROM chatbot.checkins") == "2")
    check("other_user_read_hidden", server.sql(f"SELECT count(*) FROM chatbot.checkins WHERE user_id='{b}'", actor=a) == "0")
    updated = server.sql(insert(a, 2), actor=a)
    check("atomic_upsert_preserves_id", updated == first)
    check("replacement_clears_note", server.sql("SELECT mood=2 AND note IS NULL FROM chatbot.checkins", actor=a) == "t")
    for actor, target in ((a, b), (b, a)):
        server.sql(insert(target, 1), actor=actor, error=("42501",))
    check("cross_user_insert_and_upsert_denied_both_directions")
    check("cross_user_update_has_no_rows", server.sql(f"UPDATE chatbot.checkins SET mood=1 WHERE user_id='{b}' RETURNING id", actor=a) == "")
    for actor in (inactive, psychologist, admin):
        check("restricted_profile_read_" + actor[0], server.sql("SELECT count(*) FROM chatbot.checkins", actor=actor) == "0")
        server.sql(insert(actor), actor=actor, error=("42501",))
    check("inactive_and_nonparticipant_writes_denied")
    for column, value in (("id", "gen_random_uuid()"), ("created_at", "clock_timestamp()"), ("updated_at", "clock_timestamp()")):
        server.sql(f"UPDATE chatbot.checkins SET {column}={value}", actor=a, error=("42501",))
    check("server_managed_columns_not_writable")
    server.sql("UPDATE chatbot.checkins SET date='2000-01-02'", actor=a, error=("23514",))
    server.sql(f"UPDATE chatbot.checkins SET user_id='{b}'", actor=a, error=("23514", "42501"))
    check("date_and_owner_immutable")
    for mood in (0, 6):
        server.sql(insert(a, mood), actor=a, error=("23514",))
    server.sql(insert(a, 3, "repeat('x',201)"), actor=a, error=("23514",))
    check("database_mood_and_note_constraints")
    server.sql("DELETE FROM chatbot.checkins", actor=a, error=("42501",))
    server.sql("SELECT * FROM chatbot._backend_migrations", actor=a, error=("42501",))
    server.sql("SELECT * FROM chatbot.checkins", role="anon", error=("42501",))
    server.sql("SELECT * FROM chatbot.checkins", role="service_role", error=("42501",))
    check("delete_ledger_anon_and_service_role_access_denied")
    server.sql(f"UPDATE public.users SET is_active=false WHERE id='{a}'")
    check("deactivation_hides_existing_rows", server.sql("SELECT count(*) FROM chatbot.checkins", actor=a) == "0")
    server.sql(insert(a), actor=a, error=("42501",))
    server.sql(f"UPDATE public.users SET is_active=true WHERE id='{a}'")
    check("deactivation_blocks_writes")
    server.sql(MIGRATION.read_text(encoding="utf-8-sig"), error=("P0001",))
    check("migration_replay_fails_without_overwrite", server.sql("SELECT count(*) FROM chatbot.checkins") == "2")
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda mood: server.sql(insert(a, mood), actor=a), (3, 4)))
    check("concurrent_upserts_keep_one_identity", results == [first, first]
          and server.sql(f"SELECT count(*) FROM chatbot.checkins WHERE user_id='{a}'") == "1")
    check("other_account_still_unchanged", server.sql("SELECT mood=5 AND note='synthetic-b' FROM chatbot.checkins", actor=b) == "t")
    # Prove real PostgreSQL custom-dump/restore on synthetic data only.
    dump = server.command("pg_dump", ["-w", "--format=custom"])
    require(dump.returncode == 0 and not dump.stderr, "Synthetic dump failed")
    from tools.backup_database import capture
    from tools.inspect_restore_backup import copy_row_counts
    data_sql = capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--data-only", "--file=-"],
                       env=clean_environment(), data=dump.stdout).decode("utf-8")
    counts = copy_row_counts(data_sql)
    check("offline_copy_counter_matches_native_pg_restore_output",
          counts["auth.users"] == 5 and counts["public.users"] == 5 and counts["chatbot.checkins"] == 2)
    restored = "msu_checkins_rehearsal_restored_" + uuid4().hex
    server.sql(f'CREATE DATABASE "{restored}"', database="postgres")
    result = server.command("pg_restore", ["-w", "--exit-on-error", "--single-transaction", "-d", restored], input=dump.stdout)
    require(result.returncode == 0, "Synthetic restore failed: " + repr(result.stderr[:700]))
    check("synthetic_database_dump_and_restore", server.sql("SELECT count(*) FROM chatbot.checkins", database=restored) == "2")
    profile_after = server.sql("SELECT json_build_object('count',(SELECT count(*) FROM public.users),"
                               "'acl',(SELECT relacl FROM pg_class WHERE oid='public.users'::regclass),"
                               "'policy',(SELECT qual FROM pg_policies WHERE tablename='users'))")
    check("existing_profile_rows_grants_policy_preserved", profile_before == profile_after)
    return passed


def main():
    with isolated_cluster() as server:
        passed = run_checks(server)
    report = {
        "completed_utc": datetime.now(timezone.utc).isoformat(), "postgres_version": "17.11",
        "migration_sha256": file_sha(MIGRATION), "checks_passed": passed,
        "synthetic_cluster_stopped_and_removed": True, "source_database_connections": False,
        "real_backup_decrypted": False, "real_backup_restore_tested": False,
        "hosted_migration_applied": False, "postgrest_or_supabase_auth_tested": False,
    }
    evidence = BACKEND / "docs/evidence/checkins-postgres-rehearsal.json"
    evidence.parent.mkdir(exist_ok=True)
    evidence.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("Synthetic PostgreSQL rehearsal completed; real Supabase restore remains untested.")


if __name__ == "__main__":
    main()
