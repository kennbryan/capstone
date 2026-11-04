"""Local launcher configuration tests; no server binding or live Supabase requests."""

import pytest

from tests.helpers import KEY
from tests.helpers import local_client
from tools import serve_staging as tool


def test_explicit_staging_settings_override_source_environment_and_disable_env_file(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://source-never-contact.invalid")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "sb_secret_never-use")
    seen = []
    settings_type = tool.Settings
    def settings(**kwargs):
        assert kwargs["_env_file"] is None
        configured = settings_type(**kwargs)
        assert configured.supabase_url.get_secret_value() == tool.BASE
        assert configured.supabase_publishable_key.get_secret_value() == KEY
        seen.append(configured)
        return configured
    monkeypatch.setattr(tool, "Settings", settings)
    application = tool.staging_app(KEY)
    assert len(seen) == 1
    assert {"/me", "/checkins", "/docs"}.issubset({route.path for route in application.routes})


@pytest.mark.parametrize("key,success", [(KEY, True), ("sb_secret_private-forbidden", False)])
def test_launcher_binds_loopback_separate_port_without_logging_key(key, success, monkeypatch, capsys):
    monkeypatch.setattr(tool.sys, "argv", ["serve_staging"])
    monkeypatch.setattr(tool.sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(tool.sys.stdout, "isatty", lambda: True)
    monkeypatch.setattr(tool, "getpass", lambda prompt: key)
    calls = []
    monkeypatch.setattr(tool.uvicorn, "run", lambda app, **kwargs: calls.append(kwargs))
    if success:
        tool.main()
        assert calls == [{"host": "127.0.0.1", "port": 8002, "access_log": False,
                          "proxy_headers": False, "log_level": "info", "reload": False, "workers": 1}]
    else:
        with pytest.raises(SystemExit):
            tool.main()
        assert calls == []
    assert key not in capsys.readouterr().out


@pytest.mark.parametrize("origin,expected", [
    ("http://localhost:7357", 200),
    ("http://127.0.0.1:7357", 200),
    ("https://other.invalid", 400),
])
def test_local_web_preflight_is_restricted_and_does_not_call_supabase(origin, expected):
    import asyncio
    import httpx

    async def check():
        application = tool.staging_app(KEY)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=application),
                                     base_url="http://test") as client:
            response = await client.options("/checkins", headers={
                "Origin": origin, "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type",
            })
            assert response.status_code == expected
            assert response.headers.get("access-control-allow-origin") == (origin if expected == 200 else None)
            assert "access-control-allow-credentials" not in response.headers
    asyncio.run(check())


def test_cors_does_not_bypass_authentication():
    with local_client(tool.staging_app(KEY)) as client:
        response = client.get("/me", headers={"Origin": "http://localhost:7357"})
        assert response.status_code == 401
        assert response.headers["access-control-allow-origin"] == "http://localhost:7357"
