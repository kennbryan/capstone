"""Synthetic HTTP contract tests. No real Supabase requests or .env loading."""

import asyncio
from contextlib import contextmanager

import httpx
import pytest
from pydantic import ValidationError

from app.main import create_app
from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, local_client, settings


def auth_user(user_id=USER_A, **updates):
    return {
        "id": user_id,
        "email_confirmed_at": "2026-01-01T00:00:00Z",
        "user_metadata": {"role": "SUPERADMIN", "id": USER_B},
        **updates,
    }


def profile(user_id=USER_A, **updates):
    return {
        "id": user_id,
        "full_name": "Pengguna Sintetis",
        "email": "synthetic@example.invalid",
        "role": "PARTICIPANT",
        "is_active": True,
        **updates,
    }


@contextmanager
def client_for(*, user=None, rows=None, auth_status=200, profile_status=200, fail_path=None):
    calls = []

    def handler(request):
        calls.append(request)
        assert request.method == "GET"
        assert request.url.host == "project.example.invalid"
        assert request.headers["apikey"] == KEY
        if request.url.path == fail_path:
            raise httpx.ConnectError("upstream details must remain private", request=request)
        if request.url.path == "/auth/v1/user":
            return httpx.Response(auth_status, json=auth_user() if user is None else user)
        assert request.url.path == "/rest/v1/users"
        return httpx.Response(profile_status, json=[profile()] if rows is None else rows)

    application = create_app(settings(), transport=httpx.MockTransport(handler))
    with local_client(application) as client:
        yield client, calls


def send(client, **kwargs):
    return client.get("/me", headers={"Authorization": f"Bearer {TOKEN_A}"}, **kwargs)


def test_success_matches_flutter_and_uses_verified_identity():
    with client_for(rows=[profile(password_hash="must never be returned")]) as (client, calls):
        result = send(client, params={"userId": USER_B})
        assert result.status_code == 200
        assert result.json() == {
            "id": USER_A, "displayName": "Pengguna Sintetis", "email": "synthetic@example.invalid"
        }
        assert len(calls) == 2
        assert all(r.headers["authorization"] == f"Bearer {TOKEN_A}" for r in calls)
        assert calls[1].url.params["id"] == f"eq.{USER_A}"
        assert calls[1].url.params["select"] == "id,full_name,email,role,is_active"
        assert calls[1].headers["accept-profile"] == "public"
        assert "private, no-store" in result.headers["cache-control"]


@pytest.mark.parametrize("authorization", [None, "Basic anything", "Bearer", "Bearer ", "Bearer x y", "Bearer " + "x" * 8193])
def test_missing_or_malformed_bearer_does_not_contact_supabase(authorization):
    with client_for() as (client, calls):
        headers = {} if authorization is None else {"Authorization": authorization}
        response = client.get("/me", headers=headers)
        assert response.status_code == 401
        assert response.json()["error"] == "UNAUTHORIZED"
        assert response.headers["www-authenticate"] == "Bearer"
        assert "no-store" in response.headers["cache-control"]
        assert calls == []


def test_duplicate_authorization_headers_are_rejected():
    with client_for() as (client, calls):
        response = client.get("/me", headers=[("Authorization", f"Bearer {TOKEN_A}"), ("Authorization", f"Bearer {TOKEN_B}")])
        assert response.status_code == 401
        assert calls == []


@pytest.mark.parametrize("code", ["bad_jwt", "session_not_found", "user_not_found", "no_authorization", "email_not_confirmed"])
def test_auth_rejection_stops_before_profile_query(code):
    with client_for(auth_status=401, user={"code": code}) as (client, calls):
        assert send(client).status_code == 401
        assert len(calls) == 1


def test_legacy_auth_error_shape_is_supported():
    with client_for(auth_status=401, user={"code": 401, "error_code": "bad_jwt"}) as (client, _):
        assert send(client).status_code == 401


def test_banned_user_is_forbidden():
    with client_for(auth_status=403, user={"code": "user_banned"}) as (client, _):
        assert send(client).status_code == 403


@pytest.mark.parametrize("user", [auth_user(email_confirmed_at=None), auth_user(is_anonymous=True)])
def test_unconfirmed_or_anonymous_user_is_denied(user):
    with client_for(user=user) as (client, calls):
        assert send(client).status_code == 401
        assert len(calls) == 1


@pytest.mark.parametrize("status", [301, 400, 401, 403, 404, 429, 500, 503])
def test_auth_gateway_or_unknown_failure_does_not_sign_out_users(status):
    with client_for(auth_status=status, user={"message": f"private {KEY} {TOKEN_A}"}) as (client, calls):
        result = send(client)
        assert result.status_code == 503
        assert result.headers["retry-after"] == "5"
        assert KEY not in result.text and TOKEN_A not in result.text
        assert len(calls) == 1


@pytest.mark.parametrize("rows", [[], [profile(is_active=False)], [profile(role="INJECTED_ROLE")]])
def test_missing_inactive_or_unknown_role_profile_is_forbidden(rows):
    with client_for(rows=rows) as (client, _):
        assert send(client).status_code == 403


@pytest.mark.parametrize("role", ["PARTICIPANT", "PSYCHOLOGIST", "SUPERADMIN"])
def test_me_identifies_known_roles_without_granting_other_feature_access(role):
    with client_for(rows=[profile(role=role)]) as (client, _):
        assert send(client).status_code == 200


@pytest.mark.parametrize("rows", [
    [profile(USER_B)], [profile(), profile(USER_B)], {"unexpected": "object"},
    [profile(id="not-a-uuid")], [profile(is_active="true")],
    [dict(id=USER_A)], [None],
])
def test_unexpected_profile_response_fails_closed(rows):
    with client_for(rows=rows) as (client, _):
        assert send(client).status_code == 503


@pytest.mark.parametrize("status", [301, 400, 401, 403, 404, 429, 500])
def test_profile_permission_or_gateway_errors_are_service_failures(status):
    with client_for(profile_status=status, rows={"message": "sensitive upstream body"}) as (client, _):
        result = send(client)
        assert result.status_code == 503
        assert "sensitive" not in result.text


@pytest.mark.parametrize("code", ["PGRST301", "PGRST302", "PGRST303"])
def test_token_expiring_between_auth_and_profile_requires_login(code):
    with client_for(profile_status=401, rows={"code": code}) as (client, _):
        assert send(client).status_code == 401


@pytest.mark.parametrize("path", ["/auth/v1/user", "/rest/v1/users"])
def test_network_failure_is_safe(path, caplog):
    with client_for(fail_path=path) as (client, _):
        result = send(client)
        assert result.status_code == 503
        assert "upstream details" not in result.text
        assert TOKEN_A not in caplog.text and KEY not in caplog.text


@pytest.mark.parametrize("bad_user", [{}, [], {"id": USER_A, "email_confirmed_at": "bad date"}])
def test_invalid_auth_response_is_a_service_error(bad_user):
    with client_for(user=bad_user) as (client, _):
        assert send(client).status_code == 503


@pytest.mark.parametrize("path", ["/auth/v1/user", "/rest/v1/users"])
def test_non_json_response_is_safe(path):
    def handler(request):
        if request.url.path == path:
            return httpx.Response(200, text="private malformed body")
        return httpx.Response(200, json=auth_user())

    with local_client(create_app(settings(), transport=httpx.MockTransport(handler))) as client:
        response = send(client)
        assert response.status_code == 503
        assert "private malformed body" not in response.text


def test_concurrent_users_do_not_share_tokens_or_profiles():
    async def handler(request):
        await asyncio.sleep(0)
        token = request.headers["authorization"]
        user_id = USER_A if token == f"Bearer {TOKEN_A}" else USER_B
        if request.url.path == "/auth/v1/user":
            return httpx.Response(200, json=auth_user(user_id))
        assert request.url.params["id"] == f"eq.{user_id}"
        return httpx.Response(200, json=[profile(user_id)])

    async def run():
        application = create_app(settings(), transport=httpx.MockTransport(handler))
        async with application.router.lifespan_context(application):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=application), base_url="http://test") as client:
                return await asyncio.gather(*[
                    client.get("/me", headers={"Authorization": f"Bearer {token}"})
                    for token in (TOKEN_A, TOKEN_B)
                ])

    responses = asyncio.run(run())
    assert [r.status_code for r in responses] == [200, 200]
    assert [r.json()["id"] for r in responses] == [USER_A, USER_B]


def test_openapi_documents_bearer_and_flutter_shape():
    schema = create_app(settings()).openapi()
    operation = schema["paths"]["/me"]["get"]
    assert operation["security"] == [{"HTTPBearer": []}]
    assert set(schema["components"]["schemas"]["MeResponse"]["properties"]) == {"id", "displayName", "email"}


@pytest.mark.parametrize("url", ["http://project.example.invalid", "https://host/rest/v1", "https://user:pass@host", "https://host/?secret=x", "https://host/#fragment", "https://host:bad"])
def test_invalid_configuration_is_rejected_without_showing_values(url):
    with pytest.raises(ValidationError) as error:
        settings(supabase_url=url)
    assert url not in str(error.value)


@pytest.mark.parametrize("key", ["", "sb_publishable_", "sb_secret_not_allowed", "legacy-token", "sb_publishable_with space"])
def test_only_publishable_keys_are_accepted(key):
    with pytest.raises(ValidationError):
        settings(supabase_publishable_key=key)


def test_configuration_is_masked_and_base_url_normalized():
    config = settings(supabase_url="https://project.example.invalid/")
    assert KEY not in repr(config)
    assert "project.example.invalid" not in repr(config)
    assert config.supabase_url.get_secret_value() == "https://project.example.invalid"


@pytest.mark.parametrize("body", [["bad_jwt"], {"code": ["bad_jwt"]}, {"code": {"secret": "value"}}, "error"])
def test_malformed_error_codes_never_crash_or_expose_upstream(body):
    with client_for(auth_status=401, user=body) as (client, _):
        response = send(client)
        assert response.status_code == 503
        assert response.json()["error"] == "SERVICE_UNAVAILABLE"


@pytest.mark.parametrize("path", ["/auth/v1/user", "/rest/v1/users"])
def test_upstream_timeout_is_a_service_failure(path):
    def handler(request):
        if request.url.path == path:
            raise httpx.ReadTimeout("private timeout", request=request)
        return httpx.Response(200, json=auth_user())

    with local_client(create_app(settings(), transport=httpx.MockTransport(handler))) as client:
        response = send(client)
        assert response.status_code == 503
        assert "private timeout" not in response.text
