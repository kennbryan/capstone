"""API/security contracts against MockTransport, not PostgreSQL/RLS integration tests."""

import asyncio
import json
from contextlib import contextmanager
from uuid import UUID, uuid5

import httpx
import pytest

from app.main import create_app
from app.request_limits import JsonBodyLimit
from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, local_client, settings

DATE = "2026-11-04"
QUERY = {"from": "2026-11-01", "to": "2026-11-07"}
PRIVATE_NOTE = "synthetic-private-note-never-echo"


class FakeSupabase:
    def __init__(self):
        self.calls = []
        self.records = {}
        self.role = "PARTICIPANT"
        self.active = True
        self.auth_status = 200
        self.profile_status = 200
        self.checkin_status = None
        self.checkin_body = None
        self.fail = None
        self.expired_at_storage = False

    def __call__(self, request):
        self.calls.append(request)
        assert request.url.host == "project.example.invalid"
        assert request.headers["apikey"] == KEY
        if request.headers["authorization"] not in (f"Bearer {TOKEN_A}", f"Bearer {TOKEN_B}"):
            return httpx.Response(401, json={"code": "bad_jwt"})
        user = USER_A if request.headers["authorization"] == f"Bearer {TOKEN_A}" else USER_B
        if request.url.path == "/auth/v1/user":
            return httpx.Response(self.auth_status, json={
                "id": user, "email_confirmed_at": "2026-01-01T00:00:00Z",
                "user_metadata": {"id": USER_B, "role": "SUPERADMIN"},
            })
        if request.url.path == "/rest/v1/users":
            assert request.headers["accept-profile"] == "public"
            assert request.url.params["id"] == f"eq.{user}"
            return httpx.Response(self.profile_status, json=[{
                "id": user, "full_name": "Synthetic", "email": "test@example.invalid",
                "role": self.role, "is_active": self.active,
            }])
        assert request.url.path == "/rest/v1/checkins"
        assert request.headers["accept-profile"] == "chatbot"
        assert request.url.params["select"] == "id,user_id,date,mood,note"
        if self.fail:
            raise self.fail("private upstream details", request=request)
        if self.expired_at_storage:
            return httpx.Response(401, json={"code": "PGRST301"})
        if self.checkin_status is not None:
            return httpx.Response(self.checkin_status, json=self.checkin_body)
        if request.method == "POST":
            assert request.headers["content-profile"] == "chatbot"
            assert request.headers["prefer"] == "resolution=merge-duplicates,return=representation"
            assert request.url.params["on_conflict"] == "user_id,date"
            body = json.loads(request.content)
            assert set(body) == {"user_id", "date", "mood", "note"}
            assert body["user_id"] == user
            row = {
                "id": str(uuid5(UUID(user), body["date"])),
                **body,
                "created_at": "private-field-not-in-mobile-contract",
            }
            self.records[user, body["date"]] = row
            return httpx.Response(201, json=[row])
        assert request.method == "GET"
        assert request.url.params["user_id"] == f"eq.{user}"
        assert request.url.params["order"] == "date.asc"
        assert request.url.params["limit"] == "366"
        start, end = request.url.params.get_list("date")
        assert start.startswith("gte.") and end.startswith("lte.")
        rows = [row for (owner, day), row in sorted(self.records.items())
                if owner == user and start[4:] <= day <= end[4:]]
        return httpx.Response(200, json=rows)


@contextmanager
def client_for(upstream=None):
    upstream = upstream or FakeSupabase()
    with local_client(create_app(settings(), transport=httpx.MockTransport(upstream))) as client:
        yield client, upstream


def save(client, *, token=TOKEN_A, **body):
    return client.post("/checkins", headers={"Authorization": f"Bearer {token}"},
                       json={"date": DATE, "mood": 3, **body})


def listing(client, *, token=TOKEN_A, params=None):
    return client.get("/checkins", headers={"Authorization": f"Bearer {token}"},
                      params=QUERY if params is None else params)


def test_save_read_replace_and_clear_note_match_flutter():
    with client_for() as (client, upstream):
        response = save(client, mood=4, note="  " + PRIVATE_NOTE + "  ")
        assert response.status_code == 200
        first = response.json()
        assert set(first) == {"id", "date", "mood", "note"}
        assert first["note"] == PRIVATE_NOTE
        assert listing(client).json() == [first]
        replacement = save(client, mood=2).json()
        assert replacement == {"id": first["id"], "date": DATE, "mood": 2}
        assert listing(client).json() == [replacement]
        assert len(upstream.records) == 1


def test_two_accounts_on_same_date_have_separate_payloads_and_results():
    with client_for() as (client, upstream):
        own_a = save(client, token=TOKEN_A, mood=1, note="synthetic-a").json()
        own_b = save(client, token=TOKEN_B, mood=5, note="synthetic-b").json()
        assert own_a["id"] != own_b["id"]
        assert listing(client, token=TOKEN_A).json() == [own_a]
        assert listing(client, token=TOKEN_B).json() == [own_b]
        assert len(upstream.records) == 2


def test_empty_range_is_success_and_inclusive_dates_are_forwarded():
    with client_for() as (client, upstream):
        result = listing(client, params={"from": DATE, "to": DATE})
        assert result.status_code == 200 and result.json() == []
        assert upstream.calls[-1].url.params.get_list("date") == [f"gte.{DATE}", f"lte.{DATE}"]


@pytest.mark.parametrize("body", [
    {"mood": 0}, {"mood": 6}, {"mood": True}, {"mood": "3"}, {"mood": 3.0},
    {"note": 123}, {"note": "a" * 201}, {"note": "\x00"},
    {"date": "2026-02-30"}, {"date": "20261104"}, {"date": "2026-11-04T00:00:00Z"},
    {"date": "2026-1-4"}, {"date": 0}, {"date": None},
    {"user_id": USER_B}, {"userId": USER_B}, {"role": "SUPERADMIN"}, {"id": USER_B},
    {"created_at": DATE},
])
def test_invalid_input_is_rejected_without_echoing_data(body):
    with client_for() as (client, upstream):
        result = save(client, **body)
        assert result.status_code == 422
        assert result.json()["error"] == "VALIDATION_ERROR"
        assert PRIVATE_NOTE not in result.text and USER_B not in result.text
        assert upstream.calls == []


@pytest.mark.parametrize("body", [{}, {"date": DATE}, {"mood": 3}, [], None])
def test_missing_fields_and_non_object_bodies_are_rejected(body):
    with client_for() as (client, upstream):
        result = client.post(
            "/checkins", headers={"Authorization": f"Bearer {TOKEN_A}", "Content-Type": "application/json"},
            content=json.dumps(body))
        assert result.status_code == 422 and upstream.calls == []


@pytest.mark.parametrize("note", [None, "", "  ", "\t\n"])
def test_optional_blank_note_is_cleared(note):
    with client_for() as (client, _):
        response = save(client, note=note)
        assert response.status_code == 200 and "note" not in response.json()


def test_unicode_note_at_limit_is_preserved():
    with client_for() as (client, _):
        result = save(client, note="🙂" * 200)
        assert result.status_code == 200 and result.json()["note"] == "🙂" * 200


def test_unpaired_json_surrogate_is_rejected_without_response_encoding_failure():
    with client_for() as (client, upstream):
        result = client.post(
            "/checkins", content=b'{"date":"2026-11-04","mood":3,"note":"\\ud800"}',
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN_A}"},
        )
        assert result.status_code == 422 and upstream.calls == []


@pytest.mark.parametrize("params", [
    {}, {"from": DATE}, {"to": DATE}, {"from": DATE, "to": "2026-11-03"},
    {"from": "2025-01-01", "to": "2026-01-02"}, {"from": "bad", "to": DATE},
    {**QUERY, "user_id": USER_B}, {**QUERY, "limit": "10000"},
    [("from", DATE), ("from", "2026-11-05"), ("to", "2026-11-07")],
])
def test_invalid_unknown_or_duplicate_query_is_rejected(params):
    with client_for() as (client, upstream):
        result = listing(client, params=params)
        assert result.status_code == 422 and upstream.calls == []


def test_leap_day_and_maximum_inclusive_range_are_allowed():
    with client_for() as (client, _):
        assert listing(client, params={"from": "2024-01-01", "to": "2024-12-31"}).status_code == 200


@pytest.mark.parametrize("method", ["GET", "POST"])
@pytest.mark.parametrize("authorization", [None, "Basic nope", "Bearer", "Bearer x y"])
def test_missing_or_invalid_token_never_contacts_supabase(method, authorization):
    with client_for() as (client, upstream):
        headers = {} if authorization is None else {"Authorization": authorization}
        result = (client.get("/checkins", params=QUERY, headers=headers) if method == "GET"
                  else client.post("/checkins", json={"date": DATE, "mood": 3}, headers=headers))
        assert result.status_code == 401 and upstream.calls == []


@pytest.mark.parametrize("role,active", [("PSYCHOLOGIST", True), ("SUPERADMIN", True),
                                         ("PARTICIPANT", False), ("INJECTED", True)])
@pytest.mark.parametrize("method", ["GET", "POST"])
def test_inactive_and_non_participant_profiles_never_access_storage(role, active, method):
    upstream = FakeSupabase()
    upstream.role, upstream.active = role, active
    with client_for(upstream) as (client, _):
        response = listing(client) if method == "GET" else save(client)
        assert response.status_code == 403
        assert all(call.url.path != "/rest/v1/checkins" for call in upstream.calls)


@pytest.mark.parametrize("status", [301, 400, 401, 403, 404, 409, 429, 500, 503])
@pytest.mark.parametrize("method", ["GET", "POST"])
def test_storage_errors_are_redacted_and_not_retried(status, method, caplog):
    upstream = FakeSupabase()
    upstream.checkin_status = status
    upstream.checkin_body = {"message": f"{PRIVATE_NOTE} {KEY} {TOKEN_A}"}
    with client_for(upstream) as (client, _):
        result = listing(client) if method == "GET" else save(client, note=PRIVATE_NOTE)
        assert result.status_code == 503
        assert result.json()["error"] == "CHECKINS_UNAVAILABLE"
        assert result.headers["retry-after"] == "5"
        assert "no-store" in result.headers["cache-control"]
        assert all(secret not in result.text + caplog.text for secret in (PRIVATE_NOTE, KEY, TOKEN_A))
        assert sum(call.url.path == "/rest/v1/checkins" for call in upstream.calls) == 1


@pytest.mark.parametrize("error", [httpx.ReadTimeout, httpx.ConnectError])
@pytest.mark.parametrize("method", ["GET", "POST"])
def test_network_failure_does_not_retry_writes(error, method):
    upstream = FakeSupabase()
    upstream.fail = error
    with client_for(upstream) as (client, _):
        result = listing(client) if method == "GET" else save(client)
        assert result.status_code == 503 and "private upstream" not in result.text
        assert sum(call.url.path == "/rest/v1/checkins" for call in upstream.calls) == 1


@pytest.mark.parametrize("method", ["GET", "POST"])
def test_token_expiring_after_profile_returns_401(method):
    upstream = FakeSupabase()
    upstream.expired_at_storage = True
    with client_for(upstream) as (client, _):
        result = listing(client) if method == "GET" else save(client)
        assert result.status_code == 401 and result.headers["www-authenticate"] == "Bearer"


def stored(**updates):
    return {"id": USER_A, "user_id": USER_A, "date": DATE, "mood": 3, "note": None, **updates}


@pytest.mark.parametrize("rows", [
    {}, None, [None], [stored(user_id=USER_B)], [stored(id="bad")],
    [stored(mood=True)], [stored(mood=7)], [stored(date="2026-12-01")],
    [stored(note="x" * 201)], [stored(), stored()],
    [stored(note="\x00")],
    [stored(), stored(date="2026-11-03")],
])
def test_malformed_or_other_users_storage_rows_are_never_returned(rows):
    upstream = FakeSupabase()
    upstream.checkin_status, upstream.checkin_body = 200, rows
    with client_for(upstream) as (client, _):
        response = listing(client)
        assert response.status_code == 503 and USER_B not in response.text


@pytest.mark.parametrize("rows", [[], [stored(), stored()], [stored(user_id=USER_B)],
                                 [stored(mood=4)], [stored(note="unexpected")],
                                 [stored(date="2026-11-03")]])
def test_save_requires_one_matching_row(rows):
    upstream = FakeSupabase()
    upstream.checkin_status, upstream.checkin_body = 200, rows
    with client_for(upstream) as (client, _):
        assert save(client).status_code == 503


@pytest.mark.parametrize("content", [
    '{"date":"2026-11-04","mood":3,"mood":4}',
    '{"date":"2026-11-04","mood":3,"note":"' + PRIVATE_NOTE + '",}',
    '[', '"' + PRIVATE_NOTE + '"',
])
def test_malformed_json_and_duplicate_keys_are_redacted(content):
    with client_for() as (client, upstream):
        result = client.post("/checkins", content=content,
                             headers={"Content-Type": "application/json"})
        # A scalar valid JSON value without auth may be rejected as unauthorized first.
        assert result.status_code in (401, 422)
        assert PRIVATE_NOTE not in result.text and upstream.calls == []


@pytest.mark.parametrize("content_type", [None, "text/plain", "application/x-www-form-urlencoded"])
def test_non_json_body_is_rejected(content_type):
    with client_for() as (client, upstream):
        headers = {} if content_type is None else {"Content-Type": content_type}
        result = client.post("/checkins", content="{}", headers=headers)
        assert result.status_code == 415 and upstream.calls == []


def test_oversized_body_is_rejected_before_parsing():
    with client_for() as (client, upstream):
        result = client.post("/checkins", content="x" * 4097,
                             headers={"Content-Type": "application/json"})
        assert result.status_code == 413 and upstream.calls == []
        assert "no-store" in result.headers["cache-control"]


def test_post_query_cannot_override_ownership():
    with client_for() as (client, upstream):
        result = client.post(
            "/checkins", params={"user_id": USER_B}, json={"date": DATE, "mood": 3},
            headers={"Authorization": f"Bearer {TOKEN_A}"},
        )
        assert result.status_code == 422 and upstream.calls == []


def test_duplicate_content_type_is_rejected():
    with client_for() as (client, upstream):
        result = client.post("/checkins", content="{}", headers=[
            ("Content-Type", "application/json"), ("Content-Type", "text/plain"),
        ])
        assert result.status_code == 415 and upstream.calls == []


def test_body_at_exact_byte_limit_is_allowed():
    with client_for() as (client, _):
        body = json.dumps({"date": DATE, "mood": 3}).ljust(4096)
        result = client.post("/checkins", content=body, headers={
            "Content-Type": "application/json; charset=utf-8", "Authorization": f"Bearer {TOKEN_A}",
        })
        assert result.status_code == 200


def test_body_timeout_is_safe(monkeypatch):
    class Expired:
        async def __aenter__(self):
            raise TimeoutError
        async def __aexit__(self, *args):
            pass
    monkeypatch.setattr("app.request_limits.asyncio.timeout", lambda seconds: Expired())
    async def run():
        sent = []
        async def receive():
            pytest.fail("Expired body should not be read")
        async def send(message):
            sent.append(message)
        async def must_not_run(scope, receive, send):
            pytest.fail("Timed-out request reached the application")
        await JsonBodyLimit(must_not_run)(
            {"type": "http", "path": "/checkins", "method": "POST",
             "headers": [(b"content-type", b"application/json")]}, receive, send,
        )
        return sent
    messages = asyncio.run(run())
    assert messages[0]["status"] == 408


def test_disconnected_body_does_not_reach_application():
    async def run():
        async def receive():
            return {"type": "http.disconnect"}
        async def send(message):
            pytest.fail("Disconnected client should not receive a response")
        async def must_not_run(scope, receive, send):
            pytest.fail("Disconnected request reached the application")
        await JsonBodyLimit(must_not_run)(
            {"type": "http", "path": "/checkins", "method": "POST",
             "headers": [(b"content-type", b"application/json")]}, receive, send,
        )
    asyncio.run(run())


def test_chunked_body_limit_does_not_trust_content_length():
    async def run():
        events = iter([
            {"type": "http.request", "body": b"x" * 3000, "more_body": True},
            {"type": "http.request", "body": b"x" * 3000, "more_body": False},
        ])
        sent = []
        async def receive():
            return next(events)
        async def send(message):
            sent.append(message)
        async def must_not_run(scope, receive, send):
            pytest.fail("Oversized request reached the application")
        await JsonBodyLimit(must_not_run)(
            {"type": "http", "path": "/checkins", "method": "POST",
             "headers": [(b"content-type", b"application/json"), (b"content-length", b"2")]},
            receive, send,
        )
        return sent
    messages = asyncio.run(run())
    assert messages[0]["status"] == 413


def test_concurrent_requests_never_share_authentication_or_ownership():
    upstream = FakeSupabase()
    async def handler(request):
        await asyncio.sleep(0)
        return upstream(request)
    async def run():
        app = create_app(settings(), transport=httpx.MockTransport(handler))
        async with app.router.lifespan_context(app):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
                return await asyncio.gather(*[
                    client.post("/checkins", json={"date": DATE, "mood": mood},
                                headers={"Authorization": f"Bearer {token}"})
                    for token, mood in ((TOKEN_A, 1), (TOKEN_B, 5))
                ])
    responses = asyncio.run(run())
    assert [r.status_code for r in responses] == [200, 200]
    assert [r.json()["mood"] for r in responses] == [1, 5]
    assert set(upstream.records) == {(USER_A, DATE), (USER_B, DATE)}


def test_openapi_exposes_bearer_query_and_exact_flutter_response_contract():
    schema = create_app(settings()).openapi()
    for method in ("get", "post"):
        assert schema["paths"]["/checkins"][method]["security"] == [{"HTTPBearer": []}]
    query = schema["paths"]["/checkins"]["get"]["parameters"]
    assert {item["name"] for item in query} == {"from", "to"}
    assert set(schema["components"]["schemas"]["CheckInResponse"]["properties"]) == {"id", "date", "mood", "note"}
