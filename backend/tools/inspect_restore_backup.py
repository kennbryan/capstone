"""Offline source-backup inspection for the staging restore plan. No DB writes/connections.

Only prints selected technical metadata, never data rows, role SQL, trigger bodies
or archive index. age asks for the existing backup passphrase privately.
"""

import argparse
from datetime import datetime, timezone
from getpass import GetPassWarning
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import warnings
import zipfile

from tools.backup_database import (
    BACKEND, EXPECTED_MEMBERS, MAX_MEMORY, PROJECT, REQUIRED_TOC, TOOLS,
    capture, clean_environment, decrypt_in_memory, file_sha, require, sha, verified_tools,
)

TARGET = "orxbprfixonwdwgjqmpv"
RUN = BACKEND / "private-backups/before-checkins-20261104T073010550310Z"
TARGET_EVIDENCE = BACKEND / f"docs/evidence/staging-preflight-{TARGET}.json"
REPORT = BACKEND / "docs/evidence/staging-backup-inspection.json"


def extensions(value):
    require(isinstance(value, list), "INVALID_EXTENSION_METADATA")
    result = {}
    for item in value:
        require(isinstance(item, dict), "INVALID_EXTENSION_METADATA")
        name, version = item.get("name"), item.get("version")
        require(isinstance(name, str) and re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_-]{0,99}", name)
                and isinstance(version, str) and re.fullmatch(r"[a-zA-Z0-9_.+-]{1,50}", version),
                "INVALID_EXTENSION_METADATA")
        require(name not in result, "DUPLICATE_EXTENSION_METADATA")
        result[name] = version
    return result


def copy_row_counts(script):
    """Count COPY records without returning columns or any row contents."""
    identifier = r'(?:"(?:[^"]|"")+"|[a-zA-Z_][a-zA-Z0-9_$]*)'
    header = re.compile(rf'COPY ({identifier})\.({identifier}) \([^\r\n]+\) FROM stdin;')
    counts, current = {}, None
    for line in script.splitlines():
        if current is not None:
            if line == r"\.":
                current = None
            else:
                counts[current] += 1
        elif line.startswith("COPY "):
            match = header.fullmatch(line)
            require(match is not None, "UNREVIEWED_COPY_FORMAT")
            names = [item[1:-1].replace('""', '"') if item.startswith('"') else item for item in match.groups()]
            current = ".".join(names)
            require(current not in counts, "DUPLICATE_COPY_TABLE")
            counts[current] = 0
    require(current is None, "INCOMPLETE_COPY_BLOCK")
    return counts


def inspect(data, target):
    require(target.get("target_project_ref") == TARGET and TARGET != PROJECT, "WRONG_STAGING_TARGET")
    require(target.get("initial_empty_target_candidate") is True
            and target.get("auth_user_count") == 0
            and target.get("public_application_table_count") == 0
            and target.get("database") == "postgres"
            and target.get("chatbot_schema_present") is False
            and target.get("website_profile_table_present") is False
            and target.get("website_ledger_present") is False, "STAGING_NOT_INITIAL_EMPTY_CANDIDATE")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(len(archive.namelist()) == 3 and set(archive.namelist()) == EXPECTED_MEMBERS,
                "BACKUP_MEMBERS_MISMATCH")
        require(sum(item.file_size for item in archive.infolist()) <= MAX_MEMORY, "BACKUP_TOO_LARGE")
        metadata = json.loads(archive.read("metadata.json"))
        dump = archive.read("database.dump")
        roles = archive.read("roles.sql")
    require(metadata.get("project_ref") == PROJECT, "BACKUP_PROJECT_MISMATCH")
    require(sha(dump) == metadata.get("dump_sha256") and sha(roles) == metadata.get("roles_sha256"),
            "BACKUP_CONTENT_MISMATCH")
    require(not re.search(rb"\bPASSWORD\s+'", roles, re.I), "ROLE_PASSWORD_PRESENT")
    source = metadata["source_before"]
    require(source["database"] == "postgres", "BACKUP_DATABASE_MISMATCH")
    require(isinstance(source["server_version_num"], int)
            and re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", source["server_version"]), "INVALID_SERVER_METADATA")
    source_extensions, target_extensions = extensions(source["extensions"]), extensions(target["extensions"])
    require(source_extensions == extensions(metadata["source_after"]["extensions"]), "SOURCE_CATALOG_CHANGED")
    # A sanitized environment prevents inherited production connection variables.
    index = capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--list"],
                    env=clean_environment(), data=dump).decode("utf-8")
    require(all(item in index for item in REQUIRED_TOC), "REQUIRED_ARCHIVE_OBJECT_MISSING")
    data_sql = capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--data-only", "--file=-"],
                       env=clean_environment(), data=dump, limit=MAX_MEMORY).decode("utf-8")
    row_counts = copy_row_counts(data_sql)
    del data_sql
    require(all(name in row_counts for name in ("auth.users", "public.users", "public._prisma_migrations")),
            "REQUIRED_TABLE_DATA_NOT_RENDERED")
    entries = []
    for line in index.splitlines():
        match = re.match(r"^[0-9]+;\s+[0-9]+\s+[0-9]+\s+(.+)$", line)
        if match:
            entries.append(match.group(1))
    public_tables = {row["name"] for row in source["relations"] if row["schema"] == "public"}
    missing = sorted(set(source_extensions) - set(target_extensions))
    version_differences = [name for name in sorted(set(source_extensions) & set(target_extensions))
                           if source_extensions[name] != target_extensions[name]]
    require({"users", "_prisma_migrations"}.issubset(public_tables), "WEBSITE_TABLES_MISSING")
    return {
        "status": "OFFLINE_RESTORE_INVENTORY_COMPLETE_NOT_RESTORED",
        "source_project_ref": PROJECT,
        "target_project_ref": TARGET,
        "source_server_version": source["server_version"],
        "reported_target_server_version": target["server_version"],
        "same_postgres_major": source["server_version_num"] // 10000 == target["server_version_num"] // 10000,
        "exact_server_version_match": source["server_version_num"] == target["server_version_num"],
        "source_extensions": source_extensions,
        "missing_target_extensions": missing,
        "extension_version_differences": version_differences,
        "required_archive_objects_present": True,
        "archive_entry_count": len(entries),
        "archived_table_data_entry_count": sum(item.startswith("TABLE DATA ") for item in entries),
        "archived_copy_row_counts": {name: row_counts.get(name) for name in (
            "auth.users", "auth.identities", "auth.schema_migrations", "public.users",
            "public._prisma_migrations", "storage.buckets", "storage.objects", "vault.secrets",
        )},
        "missing_copy_count_means_unverified_not_zero": True,
        "public_application_table_count": len(public_tables),
        "additional_public_table_count": len(public_tables - {"users", "_prisma_migrations"}),
        "public_function_count": sum(item.startswith("FUNCTION public ") for item in entries),
        "custom_auth_trigger_count": sum(item.startswith("TRIGGER auth ") for item in entries),
        "foreign_table_or_server_entry_count": sum(item.startswith(("FOREIGN TABLE ", "SERVER ", "USER MAPPING ")) for item in entries),
        "existing_managed_target_objects_require_selection_review": True,
        "global_role_import_requires_review": True,
        "target_evidence_source": "user-supplied SQL Editor preflight; not live-checked by this tool",
        "database_connections_made": False,
        "restore_applied": False,
        "migration_applied": False,
    }


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    require(os.name == "nt" and sys.stdin.isatty() and sys.stdout.isatty(), "PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
    warnings.simplefilter("error", GetPassWarning)
    verified_tools()
    archive = RUN / "database.zip.age"
    proof = json.loads((RUN / "verification.json").read_text(encoding="utf-8"))
    require(proof.get("status") == "ENCRYPTED_LOCAL_BACKUP_VERIFIED_NOT_RESTORED"
            and file_sha(archive) == proof.get("sha256"), "BACKUP_FILE_CHANGED")
    target = json.loads(TARGET_EVIDENCE.read_text(encoding="utf-8"))
    print("INSPEKSI OFFLINE SAJA. Tidak ada koneksi database, restore, atau migrasi.", flush=True)
    print("Masukkan passphrase BACKUP yang sudah dibuat pada prompt age berikut.", flush=True)
    data = decrypt_in_memory(archive, clean_environment())
    try:
        report = inspect(data, target)
    finally:
        data[:] = b"\x00" * len(data)
    report["completed_utc"] = datetime.now(timezone.utc).isoformat()
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print("INSPEKSI BACKUP SELESAI. Restore dan migrasi belum dijalankan.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, AttributeError,
            GetPassWarning, subprocess.SubprocessError, zipfile.BadZipFile):
        print("INSPEKSI DIHENTIKAN. Periksa arsip, passphrase atau tool lokal; jangan kirim rahasia/diagnostic mentah.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nInspeksi dihentikan; tidak ada restore atau migrasi.")
        raise SystemExit(1) from None
