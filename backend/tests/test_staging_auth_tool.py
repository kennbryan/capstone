"""Synthetic staging workflow; no network transport or real credentials."""

import asyncio
import json

import httpx
import pytest

from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B
from tools import verify_staging_auth as tool


def fake_upstream(*, leak=False, login_status=200, inactive=False):
    calls = []
    accounts = {
        email: {"id": user_id, "full_name": label, "email": email,
                "role": "PARTICIPANT", "is_active": not inactive}
        for (email, label), user_id in zip(tool.ACCOUNTS, (USER_A, USER_B))
    }
    tokens = {TOKEN_A: accounts[tool.ACCOUNTS[0][0]], TOKEN_B: accounts[tool.ACCOUNTS[1][0]]}

    def handler(request):
        calls.append(request)
        assert request.url.host == f"{tool.TARGET}.supabase.co"
        assert request.headers["apikey"] == KEY
        if request.url.path == "/auth/v1/token":
            assert request.method == "POST" and request.url.params["grant_type"] == "password"
            if login_status != 200:
                return httpx.Response(login_status, json={"private": "synthetic-private-error-body"})
            email = json.loads(request.content)["email"]
            token = TOKEN_A if email == tool.ACCOUNTS[0][0] else TOKEN_B
            return httpx.Response(200, json={"user": accounts[email], "access_token": token})
        assert request.method == "GET"
        profile = tokens[request.headers["authorization"].removeprefix("Bearer ")]
        if request.url.path == "/auth/v1/user":
            return httpx.Response(200, json={"id": profile["id"], "email_confirmed_at": "2026-01-01T00:00:00Z"})
        assert request.url.path == "/rest/v1/users"
        assert request.headers["accept-profile"] == "public"
        own = request.url.params["id"] == "eq." + profile["id"]
        return httpx.Response(200, json=[profile] if own or leak else [])

    return httpx.MockTransport(handler), calls


def test_staging_tool_checks_real_me_route_and_rls_without_source_or_profile_writes(monkeypatch, capsys):
    monkeypatch.setenv("SUPABASE_URL", "https://source-do-not-contact.invalid")
    monkeypatch.setattr(tool, "getpass", lambda prompt: "synthetic-private-password")
    transport, calls = fake_upstream()
    result = asyncio.run(tool.run(KEY, transport=transport))
    assert result["target_project_ref"] == tool.TARGET
    assert result["cross_profile_read_hidden_both_directions"] is True
    assert result["checkins_tested"] is False
    assert sum(r.method == "POST" for r in calls) == 2
    assert len(calls) == 10
    output = capsys.readouterr().out
    for private in (KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, "synthetic-private-password"):
        assert private not in output


@pytest.mark.parametrize("change,code", [
    ({"leak": True}, "STAGING_PROFILE_OR_RLS_MISMATCH"),
    ({"login_status": 400}, "STAGING_TESTER_LOGIN_FAILED"),
    ({"inactive": True}, "STAGING_ME_FAILED"),
])
def test_failed_login_profile_or_rls_never_produces_success(change, code, monkeypatch, capsys):
    monkeypatch.setattr(tool, "getpass", lambda prompt: "synthetic-password")
    transport, calls = fake_upstream(**change)
    with pytest.raises(RuntimeError, match=code):
        asyncio.run(tool.run(KEY, transport=transport))
    assert all(r.method == "GET" or r.url.path == "/auth/v1/token" for r in calls)
    assert "synthetic-private-error-body" not in capsys.readouterr().out


def test_privileged_key_is_rejected_before_login(monkeypatch):
    transport, calls = fake_upstream()
    monkeypatch.setattr(tool, "getpass", lambda prompt: pytest.fail("Must not ask for password"))
    with pytest.raises(ValueError):
        asyncio.run(tool.run("sb_secret_synthetic", transport=transport))
    assert calls == []


def test_cli_never_echoes_network_exception_or_writes_success_report_on_failure(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(tool.sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(tool.sys.stdout, "isatty", lambda: True)
    monkeypatch.setattr(tool, "getpass", lambda prompt: KEY)
    monkeypatch.setattr(tool, "REPORT", tmp_path / "report.json")
    async def fail(key):
        raise httpx.ConnectError("synthetic-private-network-details")
    monkeypatch.setattr(tool, "run", fail)
    with pytest.raises(SystemExit):
        tool.main()
    assert "synthetic-private-network-details" not in capsys.readouterr().out
    assert not tool.REPORT.exists()
