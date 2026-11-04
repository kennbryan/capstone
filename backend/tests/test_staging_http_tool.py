"""HTTP workflow contracts with synthetic responses and no network access."""

import json

import httpx
import pytest

from tests.helpers import KEY, USER_A, USER_B, TOKEN_A, TOKEN_B
from tools import verify_staging_http as tool
from tools import verify_checkins

DAY = "2000-01-01"


def upstream(*, broken_me=False, leak=False):
    calls = []
    users = {token: (user_id, email, label) for token, user_id, (email, label) in
             zip((TOKEN_A, TOKEN_B), (USER_A, USER_B), tool.ACCOUNTS)}
    rows = {USER_A: {"id": USER_A, "user_id": USER_A, "date": DAY, "mood": 2, "note": None},
            USER_B: {"id": USER_B, "user_id": USER_B, "date": DAY, "mood": 5, "note": verify_checkins.NOTE_B}}
    def handler(request):
        calls.append(request)
        local = request.url.host == "127.0.0.1"
        assert local or request.url.host == f"{tool.TARGET}.supabase.co"
        if local:
            assert request.url.port == 8002 and request.method == "GET"
        if request.method == "POST":
            assert not local and request.url.path == "/auth/v1/token"
            assert request.headers["apikey"] == KEY
            email = json.loads(request.content)["email"]
            token = TOKEN_A if email == tool.ACCOUNTS[0][0] else TOKEN_B
            return httpx.Response(200, json={"user": {"id": users[token][0], "email": email}, "access_token": token})
        token = request.headers.get("authorization", "").removeprefix("Bearer ")
        if token not in users:
            return httpx.Response(401, json={"error": "UNAUTHORIZED"})
        user_id, email, label = users[token]
        if local and request.url.path == "/me":
            return httpx.Response(200, json={"id": user_id, "displayName": "wrong" if broken_me else label, "email": email})
        if local:
            assert request.url.path == "/checkins"
            row = {k: v for k, v in rows[user_id].items() if k != "user_id" and v is not None}
            return httpx.Response(200, json=[row])
        assert request.method == "GET" and request.url.path == "/rest/v1/checkins"
        assert request.headers["accept-profile"] == "chatbot"
        target = request.url.params["user_id"].removeprefix("eq.")
        return httpx.Response(200, json=[rows[target]] if target == user_id or leak else [])
    return httpx.MockTransport(handler), calls


def test_http_reads_me_and_history_with_no_database_posts_or_secret_output(monkeypatch, capsys):
    monkeypatch.setenv("SUPABASE_URL", "https://source-never-contact.invalid")
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: "synthetic-private-password")
    transport, calls = upstream()
    report = tool.run(KEY, DAY, transport=transport)
    assert report["status"] == "STAGING_HTTP_ME_AND_CHECKINS_READBACK_VERIFIED"
    assert report["checkin_writes_performed"] is False
    assert sum(r.method == "POST" for r in calls) == 2
    assert sum(r.url.path == "/me" for r in calls) == 3
    output = capsys.readouterr().out
    for private in (KEY, USER_A, USER_B, TOKEN_A, TOKEN_B, "synthetic-private-password", verify_checkins.NOTE_B):
        assert private not in output


@pytest.mark.parametrize("options", [{"broken_me": True}, {"leak": True}])
def test_http_failure_never_returns_success(options, monkeypatch):
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: "synthetic-password")
    transport, calls = upstream(**options)
    with pytest.raises(SystemExit):
        tool.run(KEY, DAY, transport=transport)
    assert all(r.method == "GET" or r.url.path == "/auth/v1/token" for r in calls)


@pytest.mark.parametrize("url", [tool.BASE + "/rest/v1/checkins", tool.HTTP_BACKEND + "/checkins",
                                 "https://source.invalid/auth/v1/token"])
def test_adapter_rejects_every_post_except_staging_login(url):
    with pytest.raises(RuntimeError, match="HTTP_TEST_WRITES_FORBIDDEN"):
        tool.ReadClient(None).post(url)


def test_privileged_key_rejected_before_http_or_password(monkeypatch):
    monkeypatch.setattr(verify_checkins, "getpass", lambda prompt: pytest.fail("Must not prompt"))
    transport, calls = upstream()
    with pytest.raises(ValueError):
        tool.run("sb_secret_forbidden", DAY, transport=transport)
    assert calls == []
