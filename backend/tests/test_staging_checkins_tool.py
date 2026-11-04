"""Actual ASGI routes and synthetic upstream only: no .env or live network."""

import json

import httpx
import pytest

from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B
from tests.test_checkins import FakeSupabase, stored
from tools import verify_checkins
from tools import verify_staging_checkins as tool

DAY = "2000-01-01"


class StagingUpstream:
    def __init__(self, *, leak=False, allow_other_write=False):
        self.database = FakeSupabase()
        self.calls = []
        self.leak, self.allow_other_write = leak, allow_other_write

    def __call__(self, request):
        self.calls.append(request)
        assert request.url.host == f"{tool.TARGET}.supabase.co"
        assert request.headers["apikey"] == KEY
        if request.url.path == "/auth/v1/token":
            assert request.method == "POST"
            email = json.loads(request.content)["email"]
            assert email in (verify_checkins.ACCOUNT_A, verify_checkins.ACCOUNT_B)
            user, token = ((USER_A, TOKEN_A) if email == verify_checkins.ACCOUNT_A else (USER_B, TOKEN_B))
            return httpx.Response(200, json={"user": {"id": user, "email": email}, "access_token": token})
        user = USER_A if request.headers["authorization"] == f"Bearer {TOKEN_A}" else USER_B
        if request.url.path == "/rest/v1/checkins":
            assert request.headers["accept-profile"] == "chatbot"
            if request.method == "POST" and "select" not in request.url.params:
                assert request.headers["content-profile"] == "chatbot"
                assert json.loads(request.content)["user_id"] != user
                return httpx.Response(201, json=[]) if self.allow_other_write else httpx.Response(403, json={"code": "42501"})
            if request.method == "GET" and "order" not in request.url.params:
                target = request.url.params["user_id"].removeprefix("eq.")
                row = self.database.records.get((target, DAY))
                return httpx.Response(200, json=[row] if row and (target == user or self.leak) else [])
        # Reuse the independently tested fake storage for backend-originated calls;
        # assert the real destination above, then adapt its test-only host assertion.
        adapted = httpx.Request(request.method, request.url.copy_with(host="project.example.invalid"),
                                headers=request.headers, content=request.content)
        return self.database(adapted)


def test_stage_write_then_fresh_app_readback_uses_no_env_or_other_hosts(monkeypatch, capsys):
    monkeypatch.setenv("SUPABASE_URL", "https://source-never-contact.invalid")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "sb_secret_never-use")
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: "synthetic-private-password")
    upstream = StagingUpstream()
    report = tool.run(KEY, DAY, transport=httpx.MockTransport(upstream))
    assert report["status"] == "STAGING_CHECKINS_WRITE_AND_ISOLATION_VERIFIED"
    assert report["cross_user_write_rejected_both_directions_this_run"] is True
    assert len(upstream.database.records) == 2
    before = dict(upstream.database.records)
    writes = sum(r.method == "POST" and r.url.path == "/rest/v1/checkins" for r in upstream.calls)
    report = tool.run(KEY, DAY, True, transport=httpx.MockTransport(upstream))
    assert report["status"] == "STAGING_CHECKINS_READBACK_VERIFIED"
    assert report["cross_user_write_rejected_both_directions_this_run"] is False
    assert upstream.database.records == before
    assert sum(r.method == "POST" and r.url.path == "/rest/v1/checkins" for r in upstream.calls) == writes
    output = capsys.readouterr().out
    assert "restart backend" not in output
    for private in (KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, "synthetic-private-password",
                    verify_checkins.NOTE_A, verify_checkins.NOTE_B):
        assert private not in output


@pytest.mark.parametrize("owner", [USER_A, USER_B])
def test_stage_tool_stops_before_any_checkin_write_if_either_date_is_occupied(owner, monkeypatch):
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: "synthetic-password")
    upstream = StagingUpstream()
    row = stored(user_id=owner, date=DAY)
    upstream.database.records[owner, DAY] = row
    with pytest.raises(SystemExit, match="Tanggal uji sudah terisi"):
        tool.run(KEY, DAY, transport=httpx.MockTransport(upstream))
    assert upstream.database.records == {(owner, DAY): row}
    assert not any(r.method == "POST" and r.url.path == "/rest/v1/checkins" for r in upstream.calls)


@pytest.mark.parametrize("options,reason", [
    ({"leak": True}, "RLS masih memperlihatkan"),
    ({"allow_other_write": True}, "Penolakan penulisan ke akun lain belum terbukti"),
])
def test_tool_detects_broken_cross_account_isolation(options, reason, monkeypatch):
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: "synthetic-password")
    upstream = StagingUpstream(**options)
    with pytest.raises(SystemExit, match=reason):
        tool.run(KEY, DAY, transport=httpx.MockTransport(upstream))


@pytest.mark.parametrize("url", [
    "https://source.invalid/rest/v1/checkins", "http://" + tool.TARGET + ".supabase.co/rest/v1/checkins",
    tool.BASE + ".attacker.invalid/rest/v1/checkins", tool.BASE + "/auth/v1/admin/users",
    tool.BASE + "/rest/v1/users", tool.BASE + "/rest/v1/checkins#fragment",
    "http://127.0.0.1:8002/checkins", "http://127.0.0.1:8001.attacker.invalid/checkins",
])
def test_routed_client_rejects_unapproved_destinations_before_sending(url):
    client = tool.RoutedClient(None, None, None)
    with pytest.raises(RuntimeError, match="STAGING_DESTINATION_REJECTED"):
        client.get(url)


@pytest.mark.parametrize("day,key", [(DAY, "sb_secret_forbidden"), ("20000101", KEY), ("2000-02-30", KEY)])
def test_invalid_key_or_date_stops_before_password_or_network(day, key, monkeypatch):
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: pytest.fail("Must not prompt"))
    upstream = StagingUpstream()
    with pytest.raises((RuntimeError, ValueError)):
        tool.run(key, day, transport=httpx.MockTransport(upstream))
    assert upstream.calls == []


def test_cli_does_not_echo_network_failure_or_create_success_report(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(tool.sys, "argv", ["verify_staging_checkins", "--date", DAY])
    monkeypatch.setattr(tool.sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(tool.sys.stdout, "isatty", lambda: True)
    monkeypatch.setattr(tool, "BACKEND_DIR", tmp_path)
    monkeypatch.setattr(tool, "getpass", lambda prompt: KEY)
    def fail(*args):
        raise httpx.ConnectError("synthetic-private-network-error")
    monkeypatch.setattr(tool, "run", fail)
    with pytest.raises(SystemExit):
        tool.main()
    output = capsys.readouterr().out
    assert "synthetic-private-network-error" not in output
    assert "PENGUJIAN CHECK-IN STAGING: LULUS" not in output
    assert not list(tmp_path.rglob("*.json"))
