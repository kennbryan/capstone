"""Verifikasi token Supabase dengan transport palsu; tidak ada request jaringan."""

import httpx
import pytest

from app.supabase_auth import AuthRejected, AuthUnavailable, SupabaseVerifier

UID = "11111111-1111-4111-8111-111111111111"
BASE = "https://example.invalid"


def make(handler):
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return SupabaseVerifier(BASE, "sb_publishable_test", client)


def ok_handler(profile=None, user=None):
    profile = [{"id": UID, "role": "PARTICIPANT", "is_active": True}] if profile is None else profile
    user = {"id": UID, "email_confirmed_at": "2026-11-01T00:00:00Z", "is_anonymous": False} if user is None else user

    def handler(request: httpx.Request):
        assert request.headers["apikey"] == "sb_publishable_test"
        if request.url.path == "/auth/v1/user":
            return httpx.Response(200, json=user)
        assert request.url.path == "/rest/v1/users"
        assert request.url.params["id"] == f"eq.{UID}"
        return httpx.Response(200, json=profile)

    return handler


async def test_valid_token_returns_verified_id_and_is_cached():
    calls = []
    inner = ok_handler()

    def handler(request):
        calls.append(request.url.path)
        return inner(request)

    v = make(handler)
    assert await v.user_id("tok") == UID
    assert await v.user_id("tok") == UID
    assert calls.count("/auth/v1/user") == 1


@pytest.mark.parametrize("user", [
    {"id": UID, "email_confirmed_at": None, "is_anonymous": False},
    {"id": UID, "email_confirmed_at": "2026-11-01T00:00:00Z", "is_anonymous": True},
])
async def test_unconfirmed_or_anonymous_rejected(user):
    with pytest.raises(AuthRejected) as e:
        await make(ok_handler(user=user)).user_id("tok")
    assert e.value.status_code == 401


async def test_bad_jwt_is_401_but_gateway_error_is_unavailable():
    v = make(lambda r: httpx.Response(401, json={"code": "bad_jwt"}))
    with pytest.raises(AuthRejected) as e:
        await v.user_id("x")
    assert e.value.status_code == 401
    v = make(lambda r: httpx.Response(401, json={"message": "Invalid API key"}))
    with pytest.raises(AuthUnavailable):
        await v.user_id("x")


@pytest.mark.parametrize("profile", [
    [],
    [{"id": UID, "role": "PARTICIPANT", "is_active": False}],
    [{"id": UID, "role": "PSYCHOLOGIST", "is_active": True}],
])
async def test_missing_inactive_or_non_participant_profile_is_403(profile):
    with pytest.raises(AuthRejected) as e:
        await make(ok_handler(profile=profile)).user_id("tok")
    assert e.value.status_code == 403


async def test_upstream_failure_and_malformed_body_are_unavailable():
    with pytest.raises(AuthUnavailable):
        await make(lambda r: httpx.Response(500)).user_id("tok")
    with pytest.raises(AuthUnavailable):
        await make(lambda r: httpx.Response(200, text="bukan json")).user_id("tok")


def test_endpoint_accepts_supabase_token_and_maps_errors(client):
    from app.main import app

    app.state.verifier = make(ok_handler())
    try:
        r = client.post("/chatbot/messages", json={"text": "halo"}, headers={"Authorization": "Bearer tok"})
        assert r.status_code == 200, r.text

        app.state.verifier = make(lambda r: httpx.Response(401, json={"code": "bad_jwt"}))
        r = client.post("/chatbot/messages", json={"text": "halo"}, headers={"Authorization": "Bearer tok"})
        assert r.status_code == 401 and r.headers["www-authenticate"] == "Bearer"

        app.state.verifier = make(lambda r: httpx.Response(500))
        r = client.post("/chatbot/messages", json={"text": "halo"}, headers={"Authorization": "Bearer tok"})
        assert r.status_code == 503 and r.headers["retry-after"] == "5"
    finally:
        app.state.verifier = None
