"""Read-only database export to an encrypted ZIP/age bundle; never runs migrations.

Run interactively from a private Windows PowerShell terminal. Credentials are
entered with getpass; age asks for the backup passphrase on the console.
No plaintext database dump, roles file or credential file is written to disk.
Archive verification is offline parsing, NOT a full database restore rehearsal.
"""

import argparse
from datetime import datetime, timezone
from getpass import GetPassWarning, getpass
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
from urllib.parse import unquote, urlsplit
import zipfile
import warnings

import certifi

BACKEND = Path(__file__).resolve().parents[1]
TOOLS = BACKEND / ".backup-tools"
BACKUPS = BACKEND / "private-backups"
PROJECT = "bofoowyzlnfhwcstlmgp"
MAX_MEMORY = 512 * 1024 * 1024
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
EXPECTED_MEMBERS = {"database.dump", "roles.sql", "metadata.json"}
REQUIRED_TOC = (
    "TABLE public users", "TABLE DATA public users",
    "TABLE auth users", "TABLE DATA auth users",
    "TABLE public _prisma_migrations", "TABLE DATA public _prisma_migrations",
    "FUNCTION public handle_auth_user_created()", "FUNCTION public handle_auth_email_changed()",
    "TRIGGER auth users wellbeing_auth_user_created",
    "TRIGGER auth users wellbeing_auth_email_changed",
    "POLICY public users users_read_own_active_profile", "ROW SECURITY public users",
)


class PipeWriter:
    """Expose no tell/seek: Windows anonymous pipe positions are not ZIP offsets."""

    def __init__(self, stream):
        self.stream = stream

    def write(self, data):
        return self.stream.write(data)

    def flush(self):
        self.stream.flush()

# Metadata only. Never query passwords, row values, tokens or Vault secret values.
CATALOG_SQL = """
SELECT json_build_object(
 'database', current_database(), 'server_version', current_setting('server_version'),
 'server_version_num', current_setting('server_version_num')::int,
 'database_bytes', pg_database_size(current_database()),
 'database_metadata', (SELECT json_build_object('owner', pg_get_userbyid(datdba), 'acl', datacl)
                       FROM pg_database WHERE datname=current_database()),
 'extensions', (SELECT json_agg(json_build_object('name',extname,'version',extversion) ORDER BY extname) FROM pg_extension),
 'relations', (SELECT json_agg(json_build_object('schema',n.nspname,'name',c.relname,
                 'kind',c.relkind,'rls',c.relrowsecurity,'owner',pg_get_userbyid(c.relowner),
                 'acl',c.relacl,'readable',has_table_privilege(c.oid,'SELECT')) ORDER BY n.nspname,c.relname)
               FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
               WHERE c.relkind IN ('r','p') AND n.nspname NOT IN ('pg_catalog','information_schema')
                 AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp%'),
 'auth_triggers', (SELECT json_agg(pg_get_triggerdef(oid) ORDER BY tgname) FROM pg_trigger
                   WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal),
 'policies', (SELECT json_agg(row_to_json(p) ORDER BY schemaname,tablename,policyname) FROM pg_policies p),
 'role_memberships', (SELECT json_agg(json_build_object('role',parent.rolname,'member',member.rolname) ORDER BY parent.rolname,member.rolname)
                      FROM pg_auth_members m JOIN pg_roles parent ON parent.oid=m.roleid
                      JOIN pg_roles member ON member.oid=m.member),
 'roles', (SELECT json_agg(json_build_object('name',rolname,'super',rolsuper,'bypassrls',rolbypassrls,
               'inherit',rolinherit,'login',rolcanlogin) ORDER BY rolname) FROM pg_roles),
 'default_acl', (SELECT json_agg(json_build_object('creator',pg_get_userbyid(defaclrole),
                  'schema_oid',defaclnamespace,'type',defaclobjtype,'acl',defaclacl) ORDER BY defaclrole,defaclnamespace,defaclobjtype) FROM pg_default_acl),
 'chatbot_schema_present', EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='chatbot'),
 'public_profile_present', to_regclass('public.users') IS NOT NULL,
 'prisma_ledger_present', to_regclass('public._prisma_migrations') IS NOT NULL,
 'backend_connection_ssl', (SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid())
);
"""


def require(condition, code):
    if not condition:
        raise RuntimeError(code)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def connection(template, password):
    require(bool(password) and not password.startswith("sb_"), "DATABASE_PASSWORD_REQUIRED")
    # Dashboard placeholders contain literal [] that urllib otherwise treats as IPv6 syntax.
    sanitized = re.sub(r"\[(?:YOUR[-_]?PASSWORD|PASSWORD)\]", "placeholder", template.strip(), flags=re.I)
    try:
        value = urlsplit(sanitized)
        host, user, port = value.hostname or "", unquote(value.username or ""), value.port
    except ValueError:
        raise RuntimeError("WRONG_SOURCE_OR_CONNECTION_MODE") from None
    direct = host == f"db.{PROJECT}.supabase.co" and user == "postgres"
    pooler = re.fullmatch(r"[a-z0-9-]+\.pooler\.supabase\.com", host) and user == f"postgres.{PROJECT}"
    require(value.scheme in ("postgres", "postgresql") and (direct or pooler)
            and port == 5432 and value.path == "/postgres" and not value.fragment,
            "WRONG_SOURCE_OR_CONNECTION_MODE")
    # Do not pass any URL options/credentials to a command line or reuse app .env.
    return {"PGHOST": host, "PGPORT": "5432", "PGDATABASE": "postgres", "PGUSER": user,
            "PGPASSWORD": password}


def clean_environment():
    allowed = ("SystemRoot", "WINDIR", "COMSPEC", "TEMP", "TMP", "USERPROFILE", "APPDATA", "LOCALAPPDATA")
    result = {key: os.environ[key] for key in allowed if key in os.environ}
    result["PATH"] = str(TOOLS / "pgsql" / "bin") + os.pathsep + str(Path(os.environ.get("SystemRoot", "C:/Windows")) / "System32")
    result["PSQL_HISTORY"] = "NUL"
    result["PGPASSFILE"] = "NUL"
    result["PGSERVICEFILE"] = "NUL"
    return result


def verified_tools():
    manifest = json.loads((TOOLS / "manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("upstream_age_digest_verified") is True, "UNVERIFIED_AGE_TOOL")
    for name, expected in manifest["files"].items():
        path = (TOOLS / name).resolve()
        require(path.is_relative_to(TOOLS.resolve()) and path.is_file()
                and file_sha(path) == expected, "BACKUP_TOOL_CHANGED")
    for name in ("pg_dump.exe", "pg_dumpall.exe", "pg_restore.exe", "psql.exe"):
        require("pgsql/bin/" + name in manifest["files"], "BACKUP_CLIENT_MISSING")
    require("age.exe" in manifest["files"], "ENCRYPTION_TOOL_MISSING")
    return manifest


def capture(command, *, env, data=None, limit=8 * 1024 * 1024):
    # Native diagnostic text stays in memory and is never echoed (it can contain data).
    result = subprocess.run(command, input=data, capture_output=True, env=env,
                            timeout=180, creationflags=NO_WINDOW)
    if result.returncode != 0:
        diagnostic = result.stderr.lower()
        for needle, code in (
            (b"password authentication failed", "DATABASE_LOGIN_FAILED"),
            (b"certificate verify failed", "TLS_CERTIFICATE_VERIFY_FAILED"),
            (b"does not match host name", "TLS_HOSTNAME_VERIFY_FAILED"),
            (b"could not translate host name", "DATABASE_HOST_NOT_RESOLVED"),
            (b"network is unreachable", "DATABASE_NETWORK_UNREACHABLE"),
            (b"connection timed out", "DATABASE_CONNECTION_TIMEOUT"),
            (b"permission denied", "DATABASE_BACKUP_PERMISSION_DENIED"),
        ):
            if needle in diagnostic:
                raise RuntimeError(code)
    require(result.returncode == 0 and not result.stderr.strip(), "NATIVE_COMMAND_FAILED_OR_WARNED")
    require(len(result.stdout) <= limit, "CAPTURE_LIMIT_EXCEEDED")
    return result.stdout


def catalog(env):
    raw = capture([str(TOOLS / "pgsql/bin/psql.exe"), "-X", "-w", "-A", "-t",
                   "-v", "ON_ERROR_STOP=1", "-c", CATALOG_SQL], env=env)
    value = json.loads(raw)
    require(value["database"] == "postgres" and value["public_profile_present"]
            and value["prisma_ledger_present"] and not value["chatbot_schema_present"], "SOURCE_STATE_CHANGED")
    require(150000 <= value["server_version_num"] < 180000, "SERVER_VERSION_REQUIRES_TOOL_REVIEW")
    require(value["database_bytes"] <= MAX_MEMORY, "DATABASE_TOO_LARGE_FOR_MEMORY_VERIFICATION")
    return value


def archive_contents(data, tools_env):
    """Validate ZIP CRC, content hashes, required archive objects and offline SQL parse."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names = archive.namelist()
        require(len(names) == 3 and set(names) == EXPECTED_MEMBERS, "BACKUP_MEMBERS_MISMATCH")
        require(sum(item.file_size for item in archive.infolist()) <= MAX_MEMORY, "BACKUP_TOO_LARGE")
        payload = {name: archive.read(name) for name in EXPECTED_MEMBERS}
    metadata = json.loads(payload["metadata.json"])
    require(metadata["project_ref"] == PROJECT, "BACKUP_PROJECT_MISMATCH")
    require(sha(payload["database.dump"]) == metadata["dump_sha256"]
            and sha(payload["roles.sql"]) == metadata["roles_sha256"], "BACKUP_HASH_MISMATCH")
    require(payload["database.dump"].startswith(b"PGDMP"), "INVALID_POSTGRES_ARCHIVE")
    require(not re.search(rb"\bPASSWORD\s+'", payload["roles.sql"], re.I), "ROLE_PASSWORD_PRESENT")
    restore = str(TOOLS / "pgsql/bin/pg_restore.exe")
    toc = capture([restore, "--list"], env=tools_env, data=payload["database.dump"]).decode("utf-8")
    require(all(item in toc for item in REQUIRED_TOC), "REQUIRED_ARCHIVE_OBJECT_MISSING")
    # No --dbname and no connection environment: render SQL into NUL, never restore.
    capture([restore, "--exit-on-error", "--file=NUL"], env=tools_env, data=payload["database.dump"])
    return {"required_objects_checked": len(REQUIRED_TOC), "dump_bytes": len(payload["database.dump"]),
            "database_restore_tested": False}


def encrypt_export(destination, env, tools_env, before):
    age = subprocess.Popen([str(TOOLS / "age.exe"), "--passphrase", "--output", str(destination)],
                           stdin=subprocess.PIPE, env=tools_env)
    dump = None
    try:
        diagnostics = bytearray()
        dump = subprocess.Popen([str(TOOLS / "pgsql/bin/pg_dump.exe"), "-w", "--format=custom",
                                 "--compress=6", "--lock-wait-timeout=10000"],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
                                creationflags=NO_WINDOW)
        def drain():
            while chunk := dump.stderr.read(4096):
                if len(diagnostics) < 65536:
                    diagnostics.extend(chunk[:65536 - len(diagnostics)])
        reader = threading.Thread(target=drain, daemon=True)
        reader.start()
        with zipfile.ZipFile(PipeWriter(age.stdin), "w", compression=zipfile.ZIP_STORED) as archive:
            digest, size = hashlib.sha256(), 0
            with archive.open("database.dump", "w", force_zip64=True) as member:
                while chunk := dump.stdout.read(1024 * 1024):
                    size += len(chunk)
                    require(size <= MAX_MEMORY, "DUMP_TOO_LARGE")
                    digest.update(chunk)
                    member.write(chunk)
            dump.stdout.close()
            require(dump.wait(timeout=180) == 0, "PG_DUMP_FAILED")
            reader.join(timeout=10)
            require(not reader.is_alive() and not diagnostics, "PG_DUMP_WARNED")
            dump.stderr.close()
            roles = capture([str(TOOLS / "pgsql/bin/pg_dumpall.exe"), "-w", "--roles-only", "--no-role-passwords"], env=env)
            require(not re.search(rb"\bPASSWORD\s+'", roles, re.I), "ROLE_PASSWORD_PRESENT")
            after = catalog(env)
            # Never run this while another team is changing DDL/roles. Data may change;
            # pg_dump still has a consistent data snapshot, captured in the archive.
            for key in ("relations", "extensions", "auth_triggers", "policies", "roles", "role_memberships", "default_acl"):
                require(before[key] == after[key], "CATALOG_CHANGED_DURING_BACKUP")
            metadata = {
                "project_ref": PROJECT, "created_utc": datetime.now(timezone.utc).isoformat(),
                "dump_sha256": digest.hexdigest(), "roles_sha256": sha(roles),
                "source_before": before, "source_after": after,
                "migration_sha256": file_sha(BACKEND / "migrations/202611040001_checkins.sql"),
                "coverage": "Full pg_dump-accessible database; owners/ACLs retained; role passwords excluded",
                "exclusions": ["Storage object bytes", "Supabase platform configuration/signing keys",
                               "Role passwords", "Extension internals provided by compatible target"],
                "database_restore_tested": False,
            }
            archive.writestr("roles.sql", roles)
            archive.writestr("metadata.json", json.dumps(metadata, indent=2).encode("utf-8"))
        age.stdin.close()
        require(age.wait(timeout=180) == 0 and destination.stat().st_size > 100, "ENCRYPTION_FAILED")
    finally:
        for process in (dump, age):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        if dump is not None:
            for pipe in (dump.stdout, dump.stderr):
                if pipe is not None:
                    pipe.close()
        if age.stdin is not None and not age.stdin.closed:
            age.stdin.close()


def decrypt_in_memory(path, tools_env):
    # age stderr is inherited for its private console password prompt, not logged.
    process = subprocess.Popen([str(TOOLS / "age.exe"), "--decrypt", str(path)],
                               stdout=subprocess.PIPE, env=tools_env)
    output = bytearray()
    try:
        while chunk := process.stdout.read(1024 * 1024):
            output.extend(chunk)
            require(len(output) <= MAX_MEMORY, "DECRYPTED_BACKUP_TOO_LARGE")
        require(process.wait(timeout=180) == 0, "BACKUP_AUTHENTICATION_FAILED")
        return output
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process.stdout.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", type=Path, help="Verify an existing encrypted bundle offline; no DB login")
    args = parser.parse_args()
    require(os.name == "nt", "WINDOWS_REQUIRED")
    require(sys.stdin.isatty() and sys.stdout.isatty(), "PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
    warnings.simplefilter("error", GetPassWarning)
    verified_tools()
    tools_env = clean_environment()
    if args.verify:
        path = args.verify.resolve()
        require(path.is_file() and path.name.endswith(".zip.age"), "SELECT_ENCRYPTED_BACKUP")
        print("Masukkan passphrase backup di prompt age untuk verifikasi offline.", flush=True)
        data = decrypt_in_memory(path, tools_env)
        try:
            archive_contents(data, tools_env)
        finally:
            data[:] = b"\x00" * len(data)
        print("VERIFIKASI OFFLINE LULUS. Restore database belum diuji.")
        return

    print("BACKUP SAJA: tidak ada migrasi, restore, perubahan password/grants, atau upload.")
    print("URI: ambil dari Connect, Direct/Session port 5432; boleh biarkan placeholder password.")
    template = getpass("Tempel URI koneksi Supabase (tersembunyi): ")
    password = getpass("Password DATABASE Supabase (tersembunyi): ")
    pg = connection(template, password)
    template = password = None
    ca_path = Path(input("Lokasi file sertifikat CA Supabase dari Database Settings: ").strip().strip('"')).resolve()
    ca = ca_path.read_bytes()
    require(b"-----BEGIN CERTIFICATE-----" in ca and b"PRIVATE KEY" not in ca, "INVALID_CA_FILE")
    ca_bundle = TOOLS / "backup-root-ca.pem"
    ca_bundle.write_bytes(Path(certifi.where()).read_bytes() + b"\n" + ca)
    env = {**tools_env, **pg, "PGSSLMODE": "verify-full", "PGSSLROOTCERT": str(ca_bundle),
           "PGCONNECT_TIMEOUT": "15", "PGOPTIONS": "-c default_transaction_read_only=on -c statement_timeout=120000 -c lock_timeout=10000"}
    pg.clear()
    try:
        before = catalog(env)
        print("Identitas target dan prasyarat diperiksa; koneksi memakai TLS verify-full.", flush=True)
        # Refuse symlink/junction redirection of backup storage.
        for parent in (BACKEND, *BACKEND.parents):
            require(not (getattr(parent.stat(follow_symlinks=False), "st_file_attributes", 0) & 0x400), "REPARSE_DESTINATION")
        if BACKUPS.exists():
            require(not BACKUPS.is_symlink() and not (getattr(BACKUPS.stat(follow_symlinks=False), "st_file_attributes", 0) & 0x400), "REPARSE_DESTINATION")
        BACKUPS.mkdir(exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        run = BACKUPS / ("before-checkins-" + stamp)
        run.mkdir()  # Exclusive new directory; never overwrite previous backups.
        destination = run / "database.zip.age"
        print("Buat passphrase backup kuat di prompt age; jangan kosong. Simpan secara privat.", flush=True)
        encrypt_export(destination, env, tools_env, before)
    finally:
        env.pop("PGPASSWORD", None)
    print("Masukkan passphrase backup yang sama untuk memeriksa hasil enkripsi.", flush=True)
    data = decrypt_in_memory(destination, tools_env)
    try:
        verification = archive_contents(data, tools_env)
    finally:
        data[:] = b"\x00" * len(data)
    manifest = {
        "status": "ENCRYPTED_LOCAL_BACKUP_VERIFIED_NOT_RESTORED",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "file": destination.name, "bytes": destination.stat().st_size,
        "sha256": file_sha(destination), "verification": verification,
        "uploaded": False, "migration_applied": False,
    }
    (run / "verification.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("BACKUP TERENKRIPSI DAN VERIFIKASI ARSIP: LULUS")
    print("Folder:", run)
    print("SHA-256:", manifest["sha256"])
    print("Restore database belum diuji. Migrasi belum dijalankan. Tidak ada upload cloud.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, GetPassWarning, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        # Print only our own fixed error codes, never native diagnostics or input.
        known = str(error) if type(error) is RuntimeError else "BACKUP_OPERATION_FAILED"
        if not re.fullmatch(r"[A-Z_]+", known):
            known = "BACKUP_OPERATION_FAILED"
        print("BACKUP DIHENTIKAN:", known)
        print("Jangan jalankan migrasi. Arsip parsial tidak dihitung sebagai backup terverifikasi.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nBackup dihentikan. Belum ada bukti backup selesai; migrasi belum dijalankan.")
        raise SystemExit(1) from None
