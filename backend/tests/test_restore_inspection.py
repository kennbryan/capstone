"""Restore planning must remain offline and never disclose archived private values."""

import io
import json
import zipfile

import pytest

from tools import inspect_restore_backup as inspection
from tools.backup_database import PROJECT, REQUIRED_TOC, sha

PRIVATE = "private-account-token-and-row-must-never-be-reported"
EXTENSIONS = [{"name": "pgcrypto", "version": "1.3"}, {"name": "plpgsql", "version": "1.0"}]


def target(**updates):
    return {
        "target_project_ref": inspection.TARGET, "database": "postgres",
        "server_version": "17.11", "server_version_num": 170011,
        "initial_empty_target_candidate": True, "auth_user_count": 0,
        "public_application_table_count": 0, "chatbot_schema_present": False,
        "website_profile_table_present": False, "website_ledger_present": False,
        "extensions": EXTENSIONS, **updates,
    }


def archive(**updates):
    dump, roles = b"PGDMP" + PRIVATE.encode(), b"CREATE ROLE synthetic;"
    source = {
        "database": "postgres", "server_version": "17.11", "server_version_num": 170011,
        "extensions": EXTENSIONS,
        "relations": [{"schema": "public", "name": "users"}, {"schema": "public", "name": "_prisma_migrations"}],
        "private": PRIVATE, "auth_triggers": [PRIVATE], "roles": [PRIVATE],
    }
    metadata = {"project_ref": PROJECT, "dump_sha256": sha(dump), "roles_sha256": sha(roles),
                "source_before": source, "source_after": source, **updates}
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as bundle:
        bundle.writestr("database.dump", dump)
        bundle.writestr("roles.sql", roles)
        bundle.writestr("metadata.json", json.dumps(metadata))
    return output.getvalue()


@pytest.fixture
def native_index(monkeypatch):
    calls = []
    def capture(command, *, env, data, **kwargs):
        calls.append(command)
        assert "PGHOST" not in env and "PGPASSWORD" not in env
        assert not any("dbname" in arg for arg in command)
        if command[1:] == ["--data-only", "--file=-"]:
            return ("COPY auth.users (id) FROM stdin;\n" + PRIVATE + "\n\\.\n"
                    "COPY public.users (id) FROM stdin;\n" + PRIVATE + "\n\\.\n"
                    "COPY public._prisma_migrations (id) FROM stdin;\nsynthetic\n\\.\n").encode()
        assert command[1:] == ["--list"]
        return "\n".join(f"{index}; 1 1 {entry} postgres" for index, entry in enumerate(REQUIRED_TOC, 1)).encode()
    monkeypatch.setattr(inspection, "capture", capture)
    return calls


def test_reports_technical_inventory_without_rows_roles_sql_or_trigger_bodies(native_index):
    report = inspection.inspect(archive(), target())
    assert PRIVATE not in json.dumps(report)
    assert report["exact_server_version_match"] is True
    assert report["missing_target_extensions"] == []
    assert report["extension_version_differences"] == []
    assert report["database_connections_made"] is False
    assert report["restore_applied"] is False and report["migration_applied"] is False
    assert report["existing_managed_target_objects_require_selection_review"] is True
    assert report["archive_entry_count"] == 12 and len(native_index) == 2
    assert report["archived_copy_row_counts"]["auth.users"] == 1
    assert report["archived_copy_row_counts"]["vault.secrets"] is None


@pytest.mark.parametrize("updates", [
    {"target_project_ref": PROJECT}, {"target_project_ref": "unapproved-project"},
    {"auth_user_count": 1}, {"website_profile_table_present": True},
    {"chatbot_schema_present": True}, {"website_ledger_present": True},
    {"public_application_table_count": 1}, {"initial_empty_target_candidate": False},
])
def test_wrong_or_nonempty_target_stops_before_native_inspection(updates, native_index):
    with pytest.raises(RuntimeError):
        inspection.inspect(archive(), target(**updates))
    assert native_index == []


@pytest.mark.parametrize("updates", [{"project_ref": inspection.TARGET}, {"dump_sha256": "changed"}, {"roles_sha256": "changed"}])
def test_wrong_or_changed_source_backup_is_rejected(updates, native_index):
    with pytest.raises(RuntimeError):
        inspection.inspect(archive(**updates), target())
    assert native_index == []


def test_version_and_extension_differences_are_exposed_without_marking_restore_ready(native_index):
    report = inspection.inspect(archive(), target(
        server_version="18.1", server_version_num=180001,
        extensions=[{"name": "pgcrypto", "version": "1.4"}],
    ))
    assert report["same_postgres_major"] is False
    assert report["missing_target_extensions"] == ["plpgsql"]
    assert report["extension_version_differences"] == ["pgcrypto"]
    assert report["restore_applied"] is False


def test_malformed_extension_metadata_is_not_echoed(native_index):
    with pytest.raises(RuntimeError) as error:
        inspection.inspect(archive(), target(extensions=[{"name": PRIVATE + "\n", "version": "1"}]))
    assert PRIVATE not in str(error.value) and native_index == []


def test_missing_required_auth_objects_stops_inspection(monkeypatch):
    monkeypatch.setattr(inspection, "capture", lambda *args, **kwargs: b"1; 1 1 TABLE public users postgres")
    with pytest.raises(RuntimeError, match="REQUIRED_ARCHIVE_OBJECT_MISSING"):
        inspection.inspect(archive(), target())


def test_copy_counter_does_not_confuse_sql_like_row_values_with_statements():
    script = ('COPY "auth"."users" (id) FROM stdin;\n'
              'COPY private.invalid (id) FROM stdin;\n'
              '\\\\.\n'
              '\\.\n'
              'COPY public.users (id) FROM stdin;\n\\.\n')
    assert inspection.copy_row_counts(script) == {"auth.users": 2, "public.users": 0}


@pytest.mark.parametrize("script", [
    "COPY private_table FROM stdin;\n\\.\n",
    "COPY auth.users (id) FROM stdin;\nunterminated",
    "COPY auth.users (id) FROM stdin;\n\\.\nCOPY auth.users (id) FROM stdin;\n\\.\n",
])
def test_unexpected_or_incomplete_copy_data_is_not_silently_counted(script):
    with pytest.raises(RuntimeError):
        inspection.copy_row_counts(script)
