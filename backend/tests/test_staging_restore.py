"""Pinned target, selective restore, secret redaction and source-data safety contracts."""

import json

import pytest

from tools import restore_staging as restore
from tools import staging_restore_sql as sql
from tools.backup_database import PROJECT, REQUIRED_TOC

TARGET = restore.TARGET
DIRECT = f"postgresql://postgres:[YOUR-PASSWORD]@db.{TARGET}.supabase.co:5432/postgres"
POOLER = f"postgresql://postgres.{TARGET}:[YOUR-PASSWORD]@aws-0-test.pooler.supabase.com:5432/postgres"


@pytest.mark.parametrize("uri", [DIRECT, POOLER])
def test_only_explicit_staging_connection_is_accepted(uri):
    env = restore.staging_connection(uri, "synthetic-password")
    assert env["PGDATABASE"] == "postgres" and env["PGPORT"] == "5432"
    assert env["PGPASSWORD"] == "synthetic-password"


@pytest.mark.parametrize("uri", [
    DIRECT.replace(TARGET, PROJECT), POOLER.replace(TARGET, PROJECT),
    DIRECT.replace(":5432", ":6543"), DIRECT.replace("/postgres", "/other"),
    DIRECT.replace(".supabase.co", ".supabase.co.attacker.invalid"),
    POOLER.replace(TARGET, "wrong-project"), DIRECT + "#fragment",
])
def test_source_other_projects_and_transaction_pooler_never_reach_database(uri):
    with pytest.raises(RuntimeError, match="WRONG_STAGING_CONNECTION"):
        restore.staging_connection(uri, "synthetic-password")


def baseline(**updates):
    return {"database":"postgres", "operator":"postgres", "server_version_num":170011,
            "extensions":[{"name":"plpgsql","version":"1.0"}], "accounts":0,"identities":0,
            "public_tables":0,"public_profile_present":False,"public_ledger_present":False,
            "chatbot_present":False,"auth_custom_triggers":0,"public_schema_create":True,
            "auth_users_privileges":True,"auth_identities_privileges":True, **updates}


@pytest.mark.parametrize("changes", [
    {"accounts":1}, {"identities":1}, {"public_tables":1}, {"public_profile_present":True},
    {"public_ledger_present":True}, {"chatbot_present":True}, {"auth_custom_triggers":1},
    {"operator":"other"}, {"database":"other"}, {"server_version_num":180001},
    {"extensions":[]}, {"auth_users_privileges":False}, {"auth_identities_privileges":False},
])
def test_changed_target_or_missing_permissions_fail_before_writing(changes):
    source={"server_version_num":170011,"extensions":[{"name":"plpgsql","version":"1.0"}]}
    with pytest.raises(RuntimeError):
        restore.validate_target(baseline(**changes), source)


def test_copy_values_remain_copy_data_and_quoted_identifiers_are_supported():
    blocks = sql.copy_blocks('COPY "public"."users" (id, full_name) FROM stdin;\n'
                             'synthetic-id\tCOMMIT;\n\\.\n')
    assert blocks["public.users"].columns == ("id","full_name")
    assert blocks["public.users"].rows == 1
    assert "COMMIT;" in blocks["public.users"].data


@pytest.mark.parametrize("text", ["COPY public.users FROM stdin;\n\\.\n",
                                  "COPY public.users (id,id) FROM stdin;\n\\.\n",
                                  "COPY public.users (id) FROM stdin;\nno-end"])
def test_unreviewed_copy_formats_stop_before_sql_generation(text):
    with pytest.raises(RuntimeError):
        sql.copy_blocks(text)


def toc():
    return "\n".join(f"{number}; 1 1 {entry} postgres" for number,entry in enumerate(REQUIRED_TOC,1))


def test_source_acl_is_separate_from_pre_and_post_data_sections():
    public, triggers, acls = sql.select_archive(toc() + "\n50; 0 0 ACL public COLUMN users.id postgres")
    assert acls == [50] and 50 not in public
    assert len(triggers) == 2
    assert len(public) > 0


@pytest.mark.parametrize("extra", [
    "50; 1 1 TABLE public unreviewed postgres",
    "50; 1 1 FUNCTION public unreviewed() postgres",
    "50; 1 1 TRIGGER auth users unknown_hook postgres",
    "50; 1 1 TRIGGER public users unknown_hook postgres",
])
def test_unreviewed_objects_are_not_silently_imported(extra):
    with pytest.raises(RuntimeError):
        sql.select_archive(toc() + "\n" + extra)


def payload():
    blocks = {name:sql.CopyBlock(name,("id",),"synthetic\n",1) for name in (*sql.TABLES,"auth.schema_migrations")}
    return {"pre":"-- public pre", "post":"-- public post", "acls":"-- source ACL replay",
            "triggers":"-- source auth triggers", "blocks":blocks}


def test_sql_is_transactional_and_replays_acls_after_default_grant_reset():
    script = sql.build_restore_sql(payload())
    assert script.startswith("BEGIN READ WRITE;")
    assert script.index("REVOKE ALL ON public.users") < script.index("-- source ACL replay")
    assert script.index("-- source ACL replay") < script.index("REVOKE ALL ON public._prisma_migrations")
    assert script.index("-- source auth triggers") < script.index("COMMIT;")
    assert "EXCEPT ALL" in script and "ON COMMIT DROP" in script
    assert "DROP SCHEMA" not in script and "CREATE ROLE" not in script


def test_apply_does_not_put_credentials_or_private_sql_in_command_arguments(monkeypatch):
    calls=[]
    monkeypatch.setattr(restore,"build_restore_sql",lambda item:"synthetic-private-copy-data")
    class Result:
        returncode=0
        stdout=b"MSU_STAGING_RESTORE_COMMIT_OK"
        stderr=b""
    def run(command,**kwargs):
        calls.append(command)
        assert "synthetic-password" not in repr(command)
        assert "synthetic-private-copy-data" not in repr(command)
        assert kwargs["input"] == b"synthetic-private-copy-data"
        assert kwargs["capture_output"] is True
        return Result()
    monkeypatch.setattr(restore.subprocess,"run",run)
    restore.apply_snapshot({"PGPASSWORD":"synthetic-password"}, {})
    assert len(calls)==1


def test_failed_apply_does_not_echo_copy_rows_or_auto_retry(monkeypatch):
    calls=[]
    monkeypatch.setattr(restore,"build_restore_sql",lambda item:"synthetic")
    class Result:
        returncode=3
        stdout=b""
        stderr=b"private user row and password must never be echoed"
    monkeypatch.setattr(restore.subprocess,"run",lambda *args,**kwargs:calls.append(args) or Result())
    with pytest.raises(RuntimeError) as error:
        restore.apply_snapshot({}, {})
    assert "private" not in str(error.value) and len(calls)==1


@pytest.mark.parametrize("started,committed,expected,absent", [
    (False, False, "Tidak ada penulisan database", "hasil belum terkonfirmasi"),
    (True, False, "hasil belum terkonfirmasi", "Tidak ada penulisan database"),
    (True, True, "RESTORE SUDAH COMMIT", "Tidak ada penulisan database"),
])
def test_cli_failure_reports_actual_write_phase_without_retry(monkeypatch, capsys, started, committed, expected, absent):
    calls = []
    def fail(progress):
        calls.append(1)
        progress.apply_started = started
        progress.commit_confirmed = committed
        raise RuntimeError("DATABASE_LOGIN_FAILED")
    monkeypatch.setattr(restore, "main", fail)
    with pytest.raises(SystemExit) as result:
        restore.run_cli()
    output = capsys.readouterr().out
    assert result.value.code == 1 and calls == [1]
    assert expected in output and absent not in output
    assert ("bukan akun tester" in output) == (not started)


@pytest.mark.parametrize("error", [ValueError("synthetic-private-password"), KeyboardInterrupt(), EOFError()])
def test_cli_redacts_private_errors_and_handles_interruption_before_write(monkeypatch, capsys, error):
    def fail(progress):
        raise error
    monkeypatch.setattr(restore, "main", fail)
    with pytest.raises(SystemExit):
        restore.run_cli()
    output = capsys.readouterr().out
    assert "synthetic-private-password" not in output
    assert "Tidak ada penulisan database" in output
