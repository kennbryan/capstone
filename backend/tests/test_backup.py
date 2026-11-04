"""Backup safety checks using synthetic bytes and mocked native parsing; no database."""

import io
import json
from pathlib import Path
import zipfile

import pytest

from tools import backup_database as backup
from tools.prepare_backup_tools import AGE_SHA256, digest

DIRECT = f"postgresql://postgres:[YOUR-PASSWORD]@db.{backup.PROJECT}.supabase.co:5432/postgres"
POOLER = f"postgresql://postgres.{backup.PROJECT}:[YOUR-PASSWORD]@aws-0-test.pooler.supabase.com:5432/postgres"


@pytest.mark.parametrize("uri", [DIRECT, POOLER])
def test_target_is_bound_to_project_without_putting_password_in_command_line(uri):
    result = backup.connection(uri, "synthetic-database-password")
    assert result["PGDATABASE"] == "postgres" and result["PGPORT"] == "5432"
    assert result["PGPASSWORD"] == "synthetic-database-password"
    assert not any("options" in key.lower() for key in result)


@pytest.mark.parametrize("uri", [
    DIRECT.replace(backup.PROJECT, "wrong-project"),
    DIRECT.replace(":5432/", ":6543/"),
    DIRECT.replace("/postgres", "/another_db"),
    DIRECT.replace(".supabase.co", ".supabase.co.attacker.invalid"),
    DIRECT.replace("postgresql://", "https://"),
    POOLER.replace("postgres." + backup.PROJECT, "postgres.other-project"),
    DIRECT + "#fragment",
])
def test_wrong_source_and_transaction_pooler_are_rejected(uri):
    with pytest.raises(RuntimeError, match="WRONG_SOURCE"):
        backup.connection(uri, "synthetic")


@pytest.mark.parametrize("password", ["", "sb_secret_synthetic", "sb_publishable_synthetic"])
def test_api_keys_are_not_database_passwords(password):
    with pytest.raises(RuntimeError, match="DATABASE_PASSWORD_REQUIRED"):
        backup.connection(DIRECT, password)


def test_child_environment_removes_inherited_credentials_and_remote_connections(monkeypatch):
    for key in ("PGHOST", "PGDATABASE", "PGPASSWORD", "PGSERVICE", "PGOPTIONS", "DATABASE_URL", "OPENAI_API_KEY"):
        monkeypatch.setenv(key, "sensitive-synthetic-value")
    result = backup.clean_environment()
    assert "sensitive-synthetic-value" not in repr(result)
    assert "PGHOST" not in result and "PGSERVICE" not in result
    assert result["PGPASSFILE"] == "NUL" and result["PGSERVICEFILE"] == "NUL"


def make_zip(*, dump=b"PGDMPsynthetic-archive", roles=b"CREATE ROLE synthetic;", **metadata_updates):
    metadata = {"project_ref": backup.PROJECT, "dump_sha256": backup.sha(dump),
                "roles_sha256": backup.sha(roles), **metadata_updates}
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        archive.writestr("database.dump", dump)
        archive.writestr("roles.sql", roles)
        archive.writestr("metadata.json", json.dumps(metadata))
    return output.getvalue()


def test_offline_verification_never_connects_or_restores(monkeypatch):
    calls = []
    def fake_capture(command, **kwargs):
        calls.append(command)
        assert "PGHOST" not in kwargs["env"]
        assert kwargs["data"].startswith(b"PGDMP")
        if "--list" in command:
            return "\n".join(backup.REQUIRED_TOC).encode()
        assert command[1:] == ["--exit-on-error", "--file=NUL"]
        assert not any("dbname" in item for item in command)
        return b""
    monkeypatch.setattr(backup, "capture", fake_capture)
    result = backup.archive_contents(make_zip(), {})
    assert result["database_restore_tested"] is False and len(calls) == 2


@pytest.mark.parametrize("kwargs,code", [
    ({"project_ref": "wrong"}, "BACKUP_PROJECT_MISMATCH"),
    ({"dump_sha256": "wrong"}, "BACKUP_HASH_MISMATCH"),
    ({"roles_sha256": "wrong"}, "BACKUP_HASH_MISMATCH"),
    ({"dump": b"not-a-postgres-archive"}, "INVALID_POSTGRES_ARCHIVE"),
    ({"roles": b"ALTER ROLE synthetic PASSWORD 'secret';"}, "ROLE_PASSWORD_PRESENT"),
])
def test_bad_backup_content_stops_before_native_parsing(kwargs, code, monkeypatch):
    monkeypatch.setattr(backup, "capture", lambda *args, **kwargs: pytest.fail("Native parser should not run"))
    with pytest.raises(RuntimeError, match=code):
        backup.archive_contents(make_zip(**kwargs), {})


def test_wrong_zip_members_are_rejected_without_extracting_to_disk():
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        archive.writestr("../unexpected.txt", "synthetic")
    with pytest.raises(RuntimeError, match="BACKUP_MEMBERS_MISMATCH"):
        backup.archive_contents(output.getvalue(), {})


def test_missing_required_auth_objects_is_not_silently_accepted(monkeypatch):
    monkeypatch.setattr(backup, "capture", lambda *args, **kwargs: b"TABLE public users")
    with pytest.raises(RuntimeError, match="REQUIRED_ARCHIVE_OBJECT_MISSING"):
        backup.archive_contents(make_zip(), {})


def test_tool_integrity_check_rejects_modified_executable(tmp_path, monkeypatch):
    monkeypatch.setattr(backup, "TOOLS", tmp_path)
    (tmp_path / "age.exe").write_bytes(b"modified")
    (tmp_path / "manifest.json").write_text(json.dumps({
        "upstream_age_digest_verified": True, "files": {"age.exe": backup.sha(b"original")},
    }))
    with pytest.raises(RuntimeError, match="BACKUP_TOOL_CHANGED"):
        backup.verified_tools()


def test_tool_manifest_cannot_read_outside_tool_directory(tmp_path, monkeypatch):
    monkeypatch.setattr(backup, "TOOLS", tmp_path)
    (tmp_path / "manifest.json").write_text(json.dumps({
        "upstream_age_digest_verified": True, "files": {"../outside": "untrusted"},
    }))
    with pytest.raises(RuntimeError, match="BACKUP_TOOL_CHANGED"):
        backup.verified_tools()


def test_capture_rejects_native_warnings_without_echoing_them(monkeypatch, capsys):
    class Result:
        returncode = 0
        stdout = b"synthetic"
        stderr = b"private-row-or-password-must-not-be-printed"
    monkeypatch.setattr(backup.subprocess, "run", lambda *args, **kwargs: Result())
    with pytest.raises(RuntimeError, match="NATIVE_COMMAND_FAILED_OR_WARNED"):
        backup.capture(["synthetic.exe"], env={})
    assert "private-row" not in capsys.readouterr().out


@pytest.mark.parametrize("diagnostic,code", [
    (b"password authentication failed for private-account", "DATABASE_LOGIN_FAILED"),
    (b"SSL error: certificate verify failed private-details", "TLS_CERTIFICATE_VERIFY_FAILED"),
])
def test_native_login_and_tls_errors_are_classified_without_exposing_details(diagnostic, code, monkeypatch):
    class Result:
        returncode = 1
        stdout = b""
        stderr = diagnostic
    monkeypatch.setattr(backup.subprocess, "run", lambda *args, **kwargs: Result())
    with pytest.raises(RuntimeError) as error:
        backup.capture(["synthetic.exe"], env={})
    assert str(error.value) == code and "private" not in str(error.value)


def test_file_digest_matches_download_digest_format(tmp_path):
    path = tmp_path / "synthetic.zip"
    path.write_bytes(b"synthetic")
    assert digest(path) == backup.sha(b"synthetic")
    assert len(AGE_SHA256) == 64


def test_nonseekable_zip_does_not_use_misleading_windows_pipe_positions():
    class WindowsPipe:
        def __init__(self):
            self.output = io.BytesIO()
        def tell(self):
            return 0
        def seek(self, *args):
            raise OSError("A pipe cannot seek")
        def write(self, data):
            return self.output.write(data)
        def flush(self):
            pass
    pipe = WindowsPipe()
    with zipfile.ZipFile(backup.PipeWriter(pipe), "w") as archive:
        archive.writestr("first", b"first synthetic payload")
        archive.writestr("second", b"second synthetic payload")
    with zipfile.ZipFile(io.BytesIO(pipe.output.getvalue())) as archive:
        assert archive.read("first") == b"first synthetic payload"
        assert archive.read("second") == b"second synthetic payload"
