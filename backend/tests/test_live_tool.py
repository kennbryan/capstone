"""Verify operator-tool workflow with an in-process API and fake Data API only."""

import httpx
import pytest

from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B
from tests.test_checkins import DATE, client_for, stored
from tools.verify_checkins import ACCOUNT_A, ACCOUNT_B, BACKEND, run

BASE = "https://project.example.invalid"


class ToolClient:
    """Route known test hosts explicitly; has no network transport."""

    def __init__(self, local, upstream):
        self.local, self.upstream = local, upstream
        self.direct_posts = 0
        self.fail_login = False

    def get(self, url, **kwargs):
        if url.startswith(BACKEND + "/"):
            return self.local.get(url.removeprefix(BACKEND), **kwargs)
        assert url == BASE + "/rest/v1/checkins"
        request = httpx.Request("GET", url, **kwargs)
        assert request.headers["apikey"] == KEY
        user = USER_A if request.headers["authorization"] == f"Bearer {TOKEN_A}" else USER_B
        if request.url.params["user_id"] != f"eq.{user}":
            return httpx.Response(200, json=[])
        day = request.url.params["date"].removeprefix("eq.")
        row = self.upstream.records.get((user, day))
        return httpx.Response(200, json=[] if row is None else [row])

    def post(self, url, **kwargs):
        if url.startswith(BACKEND + "/"):
            return self.local.post(url.removeprefix(BACKEND), **kwargs)
        if url == BASE + "/auth/v1/token":
            if self.fail_login:
                return httpx.Response(400, json={"private": "never print this"})
            email = kwargs["json"]["email"]
            assert email in (ACCOUNT_A, ACCOUNT_B)
            user, token = (USER_A, TOKEN_A) if email == ACCOUNT_A else (USER_B, TOKEN_B)
            return httpx.Response(200, json={"user": {"id": user, "email": email}, "access_token": token})
        assert url == BASE + "/rest/v1/checkins"
        self.direct_posts += 1
        # Simulate RLS rejecting the tool's deliberate other-user write.
        user = USER_A if kwargs["headers"]["Authorization"] == f"Bearer {TOKEN_A}" else USER_B
        assert kwargs["json"]["user_id"] != user
        return httpx.Response(403, json={"code": "42501"})


def test_operator_tool_write_and_verify_only_do_not_leak_secrets(monkeypatch, capsys):
    monkeypatch.setattr("tools.verify_checkins.getpass", lambda prompt: "synthetic-password-do-not-print")
    with client_for() as (local, upstream):
        client = ToolClient(local, upstream)
        run(client, BASE, KEY, DATE, False)
        assert client.direct_posts == 2 and len(upstream.records) == 2
        writes = sum(call.method == "POST" for call in upstream.calls)
        run(client, BASE, KEY, DATE, True)
        assert sum(call.method == "POST" for call in upstream.calls) == writes
        assert client.direct_posts == 2
    output = capsys.readouterr().out
    assert "SELESAI" in output
    for secret in (KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, "synthetic-password-do-not-print"):
        assert secret not in output


@pytest.mark.parametrize("owner", [USER_A, USER_B])
def test_operator_tool_does_not_overwrite_an_occupied_test_date(owner, monkeypatch):
    monkeypatch.setattr("tools.verify_checkins.getpass", lambda prompt: "synthetic")
    with client_for() as (local, upstream):
        original = stored(user_id=owner)
        upstream.records[owner, DATE] = original
        with pytest.raises(SystemExit, match="Tanggal uji sudah terisi"):
            run(ToolClient(local, upstream), BASE, KEY, DATE, False)
        assert upstream.records == {(owner, DATE): original}
        assert not any(call.method == "POST" for call in upstream.calls)


def test_operator_tool_login_failure_stops_before_checkin_writes(monkeypatch, capsys):
    monkeypatch.setattr("tools.verify_checkins.getpass", lambda prompt: "synthetic")
    with client_for() as (local, upstream):
        client = ToolClient(local, upstream)
        client.fail_login = True
        with pytest.raises(SystemExit, match="Login gagal"):
            run(client, BASE, KEY, DATE, False)
        assert not upstream.records and client.direct_posts == 0
    assert "never print this" not in capsys.readouterr().out
