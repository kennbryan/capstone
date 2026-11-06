"""Exercise the real ASGI route with synthetic Auth, profiles and chatbot replies."""

import json
from contextlib import contextmanager

import httpx
import pytest
from pydantic import ValidationError

from app.main import create_app
from tests.helpers import KEY, TOKEN_A, TOKEN_B, USER_A, USER_B, local_client, settings
from tests.test_me import auth_user, profile

ROUTE = "/chatbot/messages"
CHAT_ORIGIN = "http://127.0.0.1:8000"
SERVICE_KEY = "synthetic-interservice-key"
MESSAGE = {"text": "Halo, saya ingin latihan napas.", "conversationId": "chat-a", "displayName": "Tester"}
REPLY = {
    "id": "message-a", "role": "assistant", "type": "normal", "text": "Mari bernapas pelan.",
    "createdAt": "2026-11-06T01:00:00Z", "conversationId": "chat-a",
    "sources": [{"articleId": "article-a", "title": "Latihan napas", "sourceName": None, "url": None}],
    "suggestions": [{"kind": "breathing", "title": "Napas tenang", "id": None}],
    "actions": [{"type": "open_activity", "label": "Coba latihan", "payload": {"steps": ["Tarik napas"]}}],
}


@contextmanager
def gateway_client(*, enabled=True, role="PARTICIPANT", active=True, chatbot=None):
    forwarded = []

    def upstream(request):
        if request.url.host == "project.example.invalid":
            assert request.method == "GET"
            assert request.headers["apikey"] == KEY
            identity = {f"Bearer {TOKEN_A}": USER_A, f"Bearer {TOKEN_B}": USER_B}.get(
                request.headers["authorization"],
            )
            if request.url.path == "/auth/v1/user":
                if identity is None:
                    return httpx.Response(401, json={"error_code": "bad_jwt"})
                return httpx.Response(200, json=auth_user(identity))
            assert request.url.path == "/rest/v1/users"
            assert request.url.params["id"] == f"eq.{identity}"
            return httpx.Response(200, json=[profile(identity, role=role, is_active=active)])
        assert str(request.url) == CHAT_ORIGIN + ROUTE
        forwarded.append(request)
        return chatbot(request) if chatbot is not None else httpx.Response(200, json=REPLY)

    configured = settings(**(
        {"chatbot_base_url": CHAT_ORIGIN, "chatbot_service_key": SERVICE_KEY} if enabled else {}
    ))
    with local_client(create_app(configured, transport=httpx.MockTransport(upstream))) as client:
        yield client, forwarded


@pytest.mark.parametrize("token", [None, "synthetic.invalid.token", "demo-session-usr_demo_a"])
def test_missing_fake_and_demo_tokens_never_reach_chatbot(token):
    headers = {} if token is None else {"Authorization": f"Bearer {token}"}
    with gateway_client() as (client, forwarded):
        response = client.post(ROUTE, json=MESSAGE, headers=headers)
        assert response.status_code == 401
        assert response.json()["error"] == "UNAUTHORIZED"
        assert not forwarded


@pytest.mark.parametrize(("token", "identity", "reply_type"), [
    (TOKEN_A, USER_A, "normal"),
    (TOKEN_B, USER_B, "crisis"),
])
def test_verified_identity_is_forwarded_and_mobile_reply_survives(token, identity, reply_type):
    expected = {**REPLY, "type": reply_type}
    with gateway_client(chatbot=lambda _: httpx.Response(200, json={
        **expected, "private_debug": "must not be returned",
    })) as (client, forwarded):
        response = client.post(ROUTE, json=MESSAGE, headers={
            "Authorization": f"Bearer {token}", "X-User-Id": "spoofed", "X-Service-Key": "spoofed",
            "Cookie": "private=inbound-only",
        })
        assert response.status_code == 200
        assert response.json() == expected
        assert "no-store" in response.headers["cache-control"]
        request, = forwarded
        assert request.method == "POST"
        assert request.headers["x-user-id"] == identity
        assert request.headers["x-service-key"] == SERVICE_KEY
        assert not {"authorization", "apikey", "cookie"} & request.headers.keys()
        assert json.loads(request.content) == MESSAGE


@pytest.mark.parametrize(("role", "active"), [("PSYCHOLOGIST", True), ("PARTICIPANT", False)])
def test_inactive_or_other_role_cannot_send_chat(role, active):
    with gateway_client(role=role, active=active) as (client, forwarded):
        response = client.post(ROUTE, json=MESSAGE, headers={"Authorization": f"Bearer {TOKEN_A}"})
        assert response.status_code == 403
        assert not forwarded


@pytest.mark.parametrize(("path", "body", "content_type", "status"), [
    (ROUTE, b'{"text":"hello","userId":"spoofed"}', "application/json", 422),
    (ROUTE + "?userId=spoofed", b'{"text":"hello"}', "application/json", 422),
    (ROUTE, b'{"text":"one","text":"two"}', "application/json", 422),
    (ROUTE, b'{"text":" "}', "application/json", 422),
    (ROUTE, br'{"text":"\ud800"}', "application/json", 422),
    (ROUTE, b"x" * (64 * 1024 + 1), "application/json", 413),
    (ROUTE, b"hello", "text/plain", 415),
])
def test_invalid_or_oversized_requests_are_rejected(path, body, content_type, status):
    with gateway_client() as (client, forwarded):
        response = client.post(path, content=body, headers={
            "Authorization": f"Bearer {TOKEN_A}", "Content-Type": content_type,
        })
        assert response.status_code == status
        assert not forwarded


def test_maximum_length_unicode_message_fits_request_limit():
    payload = {"text": "🌿" * 4000}
    with gateway_client() as (client, forwarded):
        response = client.post(ROUTE, content=json.dumps(payload), headers={
            "Authorization": f"Bearer {TOKEN_A}", "Content-Type": "application/json",
        })
        assert response.status_code == 200
        assert json.loads(forwarded[0].content) == payload


def test_chatbot_response_cookie_is_never_replayed_to_another_account():
    with gateway_client(chatbot=lambda _: httpx.Response(
        200, json=REPLY, headers={"Set-Cookie": "session=private; Path=/"},
    )) as (client, forwarded):
        for token in (TOKEN_A, TOKEN_B):
            response = client.post(ROUTE, json=MESSAGE, headers={"Authorization": f"Bearer {token}"})
            assert response.status_code == 200
            assert "set-cookie" not in response.headers
        assert [request.headers["x-user-id"] for request in forwarded] == [USER_A, USER_B]
        assert all("cookie" not in request.headers for request in forwarded)


@pytest.mark.parametrize("chatbot", [
    lambda _: httpx.Response(401, json={"detail": "private upstream error"}),
    lambda _: httpx.Response(302, headers={"Location": "https://redirect.example.invalid/"}),
    lambda _: httpx.Response(200, json={"text": "private invalid reply"}),
    lambda _: httpx.Response(200, content=b"x" * (256 * 1024 + 1), headers={"Content-Type": "application/json"}),
    lambda _: httpx.Response(200, content=json.dumps({
        **REPLY, "actions": [{"type": "open_activity", "label": "test", "payload": {"durationMin": float("nan")}}],
    }), headers={"Content-Type": "application/json"}),
])
def test_invalid_upstream_result_is_safe_and_never_retried(chatbot):
    with gateway_client(chatbot=chatbot) as (client, forwarded):
        response = client.post(ROUTE, json=MESSAGE, headers={"Authorization": f"Bearer {TOKEN_A}"})
        assert response.status_code == 503
        assert response.json()["error"] == "CHATBOT_UNAVAILABLE"
        assert "private" not in response.text
        assert len(forwarded) == 1


def test_upstream_timeout_is_redacted_and_never_retried():
    def timeout(request):
        raise httpx.ReadTimeout("private upstream details", request=request)

    with gateway_client(chatbot=timeout) as (client, forwarded):
        response = client.post(ROUTE, json=MESSAGE, headers={"Authorization": f"Bearer {TOKEN_A}"})
        assert response.status_code == 503
        assert response.json()["error"] == "CHATBOT_UNAVAILABLE"
        assert "private upstream" not in response.text
        assert len(forwarded) == 1


def test_gateway_without_configuration_keeps_other_endpoints_available():
    with gateway_client(enabled=False) as (client, forwarded):
        headers = {"Authorization": f"Bearer {TOKEN_A}"}
        assert client.get("/me", headers=headers).status_code == 200
        assert ROUTE in client.get("/openapi.json").json()["paths"]
        response = client.post(ROUTE, json=MESSAGE, headers=headers)
        assert response.status_code == 503
        assert response.json()["error"] == "CHATBOT_UNAVAILABLE"
        assert not forwarded


@pytest.mark.parametrize("overrides", [
    {"chatbot_base_url": CHAT_ORIGIN},
    {"chatbot_service_key": SERVICE_KEY},
    {"chatbot_base_url": "http://outside.example.invalid", "chatbot_service_key": SERVICE_KEY},
    {"chatbot_base_url": "https://inside.example.invalid/path", "chatbot_service_key": SERVICE_KEY},
    {"chatbot_base_url": CHAT_ORIGIN, "chatbot_service_key": "bad\r\nheader"},
])
def test_gateway_configuration_requires_a_safe_url_and_key_pair(overrides):
    with pytest.raises(ValidationError):
        settings(**overrides)
