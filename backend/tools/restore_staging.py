"""Restore the reviewed application/email-account snapshot ONLY to the pinned staging project.

Default mode is read-only planning. --apply writes staging in one transaction.
No source connection, application .env, role import, platform clone or check-in migration.
"""

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
from getpass import GetPassWarning, getpass
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit
import warnings
import zipfile

from tools.backup_database import (
    BACKEND, EXPECTED_MEMBERS, MAX_MEMORY, PROJECT, TOOLS, capture, clean_environment,
    decrypt_in_memory, file_sha, require, sha, verified_tools,
)
from tools.inspect_restore_backup import RUN, TARGET, extensions
from tools.staging_restore_sql import TABLES, build_restore_sql, prepare_payload

REPORT = BACKEND / "docs/evidence/staging-application-restore.json"
PREFLIGHT = """
SELECT json_build_object(
 'database',current_database(), 'operator',current_user,
 'server_version_num',current_setting('server_version_num')::int,
 'accounts',(SELECT count(*) FROM auth.users),
 'identities',(SELECT count(*) FROM auth.identities),
 'auth_migrations',(SELECT count(*) FROM auth.schema_migrations),
 'public_profile_present',to_regclass('public.users') IS NOT NULL,
 'public_ledger_present',to_regclass('public._prisma_migrations') IS NOT NULL,
 'chatbot_present',EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='chatbot'),
 'auth_custom_triggers',(SELECT count(*) FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal),
 'public_tables',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                   WHERE n.nspname='public' AND c.relkind IN ('r','p') AND NOT EXISTS
                     (SELECT 1 FROM pg_depend d WHERE d.classid='pg_class'::regclass
                       AND d.objid=c.oid AND d.deptype='e' AND d.refclassid='pg_extension'::regclass)),
 'public_schema_create',has_schema_privilege('public','CREATE'),
 'auth_users_privileges',has_table_privilege('auth.users','SELECT') AND has_table_privilege('auth.users','INSERT')
   AND has_table_privilege('auth.users','REFERENCES') AND has_table_privilege('auth.users','TRIGGER'),
 'auth_identities_privileges',has_table_privilege('auth.identities','SELECT') AND has_table_privilege('auth.identities','INSERT'),
 'extensions',(SELECT json_agg(json_build_object('name',extname,'version',extversion) ORDER BY extname) FROM pg_extension)
);
"""


def staging_connection(template, password):
    require(TARGET != PROJECT and bool(password) and not password.startswith("sb_"), "STAGING_DATABASE_PASSWORD_REQUIRED")
    template = re.sub(r"\[(?:YOUR[-_]?PASSWORD|PASSWORD)\]", "placeholder", template.strip(), flags=re.I)
    try:
        value = urlsplit(template)
        host, user, port = value.hostname or "", unquote(value.username or ""), value.port
    except ValueError:
        raise RuntimeError("WRONG_STAGING_CONNECTION") from None
    direct = host == f"db.{TARGET}.supabase.co" and user == "postgres"
    pooled = re.fullmatch(r"[a-z0-9-]+\.pooler\.supabase\.com", host) and user == f"postgres.{TARGET}"
    require(value.scheme in ("postgres", "postgresql") and (direct or pooled)
            and port == 5432 and value.path == "/postgres" and not value.fragment,
            "WRONG_STAGING_CONNECTION")
    return {"PGHOST": host, "PGUSER": user, "PGPORT": "5432", "PGDATABASE": "postgres", "PGPASSWORD": password}


def target_catalog(env):
    data = capture([str(TOOLS / "pgsql/bin/psql.exe"), "-X", "-w", "-q", "-A", "-t",
                    "-v", "ON_ERROR_STOP=1", "-c", PREFLIGHT], env=env)
    return json.loads(data)


def validate_target(target, source):
    require(target["database"] == "postgres" and target["operator"] == "postgres", "WRONG_STAGING_DATABASE_OPERATOR")
    require(target["server_version_num"] == source["server_version_num"], "POSTGRES_VERSION_DIFFERENCE")
    require(extensions(target["extensions"]) == extensions(source["extensions"]), "EXTENSION_BASELINE_DIFFERENCE")
    require(target["accounts"] == 0 and target["identities"] == 0 and target["public_tables"] == 0
            and not target["public_profile_present"] and not target["public_ledger_present"]
            and not target["chatbot_present"] and target["auth_custom_triggers"] == 0,
            "STAGING_NOT_EMPTY_STOP_NO_OVERWRITE")
    require(target["public_schema_create"] and target["auth_users_privileges"]
            and target["auth_identities_privileges"], "STAGING_RESTORE_PRIVILEGES_MISSING")


def load_snapshot(data):
    with zipfile.ZipFile(io.BytesIO(data)) as bundle:
        require(len(bundle.namelist()) == 3 and set(bundle.namelist()) == EXPECTED_MEMBERS,
                "BACKUP_MEMBERS_MISMATCH")
        require(sum(item.file_size for item in bundle.infolist()) <= MAX_MEMORY, "BACKUP_TOO_LARGE")
        metadata = json.loads(bundle.read("metadata.json"))
        dump, roles = bundle.read("database.dump"), bundle.read("roles.sql")
    require(metadata["project_ref"] == PROJECT and sha(dump) == metadata["dump_sha256"]
            and sha(roles) == metadata["roles_sha256"], "BACKUP_CONTENT_MISMATCH")
    public = {item["name"] for item in metadata["source_before"]["relations"] if item["schema"] == "public"}
    require(public == {"users", "_prisma_migrations"}, "UNREVIEWED_APPLICATION_TABLES")
    return metadata, dump


def apply_snapshot(env, payload):
    sql = build_restore_sql(payload)
    # -f stdin, fixed database/env and no command-line password. ON_ERROR_STOP aborts
    # the open transaction on errors; no --clean/--create/role SQL is ever used.
    result = subprocess.run(
        [str(TOOLS / "pgsql/bin/psql.exe"), "-X", "-w", "-q", "-A", "-t",
         "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate", "-f", "-"],
        input=sql.encode("utf-8"), capture_output=True, env=env, timeout=180,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    # Never print stderr: it can include COPY input if server verbosity differs.
    require(result.returncode == 0 and b"MSU_STAGING_RESTORE_COMMIT_OK" in result.stdout,
            "STAGING_APPLY_NOT_CONFIRMED_STOP_AND_INSPECT_TARGET")


@dataclass
class RestoreProgress:
    apply_started: bool = False
    commit_confirmed: bool = False


def report_failure(error, progress):
    code = str(error) if type(error) is RuntimeError and re.fullmatch(r"[A-Z_]+", str(error)) else "STAGING_RESTORE_OPERATION_FAILED"
    print("PEMULIHAN DIHENTIKAN:", code)
    if progress.commit_confirmed:
        print("RESTORE SUDAH COMMIT. Jangan mengulang impor; periksa laporan lokal.")
    elif progress.apply_started:
        print("APPLY sudah dimulai; hasil belum terkonfirmasi. Periksa target sebelum mencoba lagi.")
    else:
        print("Belum ada perintah restore yang dikirim. Tidak ada penulisan database oleh skrip ini.")
        if code == "DATABASE_LOGIN_FAILED":
            print("Periksa URI Connect dan password DATABASE milik project STAGING, bukan akun tester atau passphrase backup.")
    print("Tidak ada retry otomatis.")


def main(progress=None):
    if progress is None:
        progress = RestoreProgress()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Apply reviewed application snapshot to the pinned staging project")
    parser.add_argument("--ca", type=Path, default=TOOLS / "backup-root-ca.pem", help="CA bundle for TLS verify-full")
    args = parser.parse_args()
    require(os.name == "nt" and sys.stdin.isatty() and sys.stdout.isatty(), "PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
    warnings.simplefilter("error", GetPassWarning)
    verified_tools()
    proof = json.loads((RUN / "verification.json").read_text(encoding="utf-8"))
    archive = RUN / "database.zip.age"
    require(proof.get("status") == "ENCRYPTED_LOCAL_BACKUP_VERIFIED_NOT_RESTORED"
            and file_sha(archive) == proof["sha256"], "BACKUP_FILE_CHANGED")
    ca = args.ca.resolve()
    require(ca.is_file() and b"-----BEGIN CERTIFICATE-----" in ca.read_bytes(), "STAGING_CA_BUNDLE_MISSING")
    print("Target staging:", TARGET)
    print("Scope: akun + identitas + profil + ledger aplikasi; login ulang di staging.")
    print("Mode:", "APPLY STAGING DALAM SATU TRANSAKSI" if args.apply else "PLAN READ-ONLY")
    template = getpass("URI Connect project STAGING port 5432 (tersembunyi): ")
    password = getpass("Password DATABASE STAGING (tersembunyi): ")
    connection = staging_connection(template, password)
    template = password = None
    env = {**clean_environment(), **connection, "PGSSLMODE": "verify-full", "PGSSLROOTCERT": str(ca),
           "PGCONNECT_TIMEOUT": "15", "PGOPTIONS": "-c default_transaction_read_only=on -c statement_timeout=120000 -c lock_timeout=5000"}
    connection.clear()
    try:
        target = target_catalog(env)
        print("Target diperiksa melalui koneksi staging TLS verify-full.", flush=True)
        print("Masukkan passphrase BACKUP pada prompt age berikut.", flush=True)
        data = decrypt_in_memory(archive, clean_environment())
        try:
            metadata, dump = load_snapshot(data)
            validate_target(target, metadata["source_before"])
            payload = prepare_payload(dump)
        finally:
            data[:] = b"\x00" * len(data)
        require(target["auth_migrations"] == payload["blocks"]["auth.schema_migrations"].rows,
                "AUTH_BASELINE_MIGRATION_COUNT_DIFFERENCE")
        counts = {name: payload["blocks"][name].rows for name in TABLES}
        print("Rencana jumlah baris:", json.dumps(counts))
        print("Role global, konfigurasi platform dan sesi login lama tidak diimpor.")
        if not args.apply:
            print("PLAN SELESAI. Belum ada penulisan. Gunakan --apply untuk menjalankan rencana staging.")
            return
        print("Memulihkan snapshot aplikasi ke staging; hasil diperiksa sebelum COMMIT.", flush=True)
        progress.apply_started = True
        apply_snapshot(env, payload)
        progress.commit_confirmed = True
        report = {
            "status": "STAGING_APPLICATION_SNAPSHOT_COMMITTED_AND_VERIFIED",
            "completed_utc": datetime.now(timezone.utc).isoformat(),
            "source_project_ref": PROJECT, "target_project_ref": TARGET,
            "backup_sha256": proof["sha256"], "restored_row_counts": counts,
            "row_snapshot_equality_verified_in_transaction": True,
            "auth_migration_baseline_verified_without_replacement": True,
            "source_database_connections": False, "global_roles_replaced": False,
            "old_login_sessions_copied": False, "ledger_client_access_restricted": True,
            "full_platform_restore_tested": False, "checkins_migration_applied": False,
            "login_after_restore_tested": False,
        }
        try:
            REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
        except OSError:
            print("RESTORE SUDAH COMMIT; laporan lokal gagal ditulis. Jangan mengulang impor.")
            raise SystemExit(1) from None
        print(json.dumps(report, indent=2))
        print("PEMULIHAN SNAPSHOT APLIKASI DI STAGING: LULUS. Migrasi check-in belum dijalankan.")
    finally:
        env.pop("PGPASSWORD", None)


def run_cli():
    progress = RestoreProgress()
    try:
        main(progress)
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, AttributeError,
            GetPassWarning, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        report_failure(error, progress)
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        report_failure(RuntimeError("OPERATOR_CANCELLED"), progress)
        raise SystemExit(1) from None


if __name__ == "__main__":
    run_cli()
