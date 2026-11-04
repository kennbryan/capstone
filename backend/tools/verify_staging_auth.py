"""Verify two restored tester accounts against staging and the real in-process /me route.

No .env reads, source requests, account/profile changes, check-ins or migrations.
Password login creates staging Auth sessions; tokens stay in process memory only.
"""

import asyncio
from datetime import datetime, timezone
from getpass import GetPassWarning, getpass
import json
import re
import sys
import warnings
from uuid import UUID

import httpx

from app.config import BACKEND_DIR, Settings
from app.main import create_app
from tools.restore_staging import TARGET

BASE = f"https://{TARGET}.supabase.co"
ACCOUNTS = (
    ("admin.tester@example.invalid", "Admin Tester"),
    ("tester.kedua@example.invalid", "Tester Kedua"),
)
REPORT = BACKEND_DIR / "docs/evidence/staging-auth-verification.json"


def require(condition, code):
    if not condition:
        raise RuntimeError(code)


async def run(key, *, transport=None):
    configured = Settings(_env_file=None, supabase_url=BASE, supabase_publishable_key=key)
    key = configured.supabase_publishable_key.get_secret_value()
    application = create_app(configured, transport=transport)
    sessions = []
    async with httpx.AsyncClient(timeout=20, follow_redirects=False, trust_env=False,
                                 transport=transport) as upstream:
        async with application.router.lifespan_context(application):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=application),
                                         base_url="http://in-process", trust_env=False) as backend:
                response = await backend.get("/me")
                require(response.status_code == 401, "MISSING_TOKEN_NOT_REJECTED")
                print("GET /me tanpa token: HTTP 401 — LULUS")
                for email, label in ACCOUNTS:
                    response = await upstream.post(
                        BASE + "/auth/v1/token", params={"grant_type": "password"},
                        headers={"apikey": key},
                        json={"email": email, "password": getpass("Password " + label + " di STAGING: ")},
                    )
                    print("Login " + label + ": HTTP", response.status_code)
                    require(response.status_code == 200, "STAGING_TESTER_LOGIN_FAILED")
                    session = response.json()
                    user_id = str(UUID(session["user"]["id"]))
                    require(session["user"]["email"].lower() == email, "LOGIN_IDENTITY_MISMATCH")
                    token = session["access_token"]
                    require(isinstance(token, str) and bool(token), "LOGIN_TOKEN_MISSING")
                    sessions.append((user_id, token, email, label))

                require(sessions[0][0] != sessions[1][0], "TESTERS_MUST_HAVE_DIFFERENT_IDS")
                for own, other in ((sessions[0], sessions[1]), (sessions[1], sessions[0])):
                    user_id, token, email, label = own
                    headers = {"apikey": key, "Authorization": "Bearer " + token, "Accept-Profile": "public"}
                    response = await backend.get("/me", headers={"Authorization": headers["Authorization"]})
                    print("GET /me " + label + ": HTTP", response.status_code)
                    require(response.status_code == 200, "STAGING_ME_FAILED")
                    require(response.json() == {"id": user_id, "displayName": label, "email": email},
                            "STAGING_ME_CONTRACT_MISMATCH")
                    for target_id, is_own in ((user_id, True), (other[0], False)):
                        response = await upstream.get(
                            BASE + "/rest/v1/users", headers=headers,
                            params={"select": "id,full_name,email,role,is_active", "id": "eq." + target_id},
                        )
                        require(response.status_code == 200, "STAGING_PROFILE_DATA_API_FAILED")
                        expected = [{"id": user_id, "full_name": label, "email": email,
                                     "role": "PARTICIPANT", "is_active": True}] if is_own else []
                        require(response.json() == expected, "STAGING_PROFILE_OR_RLS_MISMATCH")
                    print("Profil aktif, PARTICIPANT, dan isolasi akses " + label + ": LULUS")
    return {
        "status": "STAGING_TWO_TESTER_LOGIN_ME_AND_PROFILE_RLS_VERIFIED",
        "completed_utc": datetime.now(timezone.utc).isoformat(),
        "target_project_ref": TARGET, "tester_count": 2,
        "backend_route_execution": "in-process FastAPI ASGI; no HTTP listener tested",
        "missing_token_rejected": True, "own_profile_contract_verified": True,
        "cross_profile_read_hidden_both_directions": True,
        "source_requests_made": False, "env_file_read_or_changed": False,
        "checkins_migration_applied_by_tool": False, "checkins_tested": False,
        "auth_sessions_created": True,
    }


def main():
    try:
        require(sys.stdin.isatty() and sys.stdout.isatty(), "PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
        warnings.simplefilter("error", GetPassWarning)
        print("Target STAGING:", TARGET)
        print("Uji login dan /me melalui kode FastAPI dalam proses; server port 8001 tidak digunakan.")
        print("Tidak mengubah .env/profil dan tidak menjalankan migrasi. Login membuat sesi Auth staging.")
        report = asyncio.run(run(getpass("Publishable key milik project STAGING (tersembunyi): ")))
        REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("PENGUJIAN LOGIN, /me, DAN RLS PROFIL STAGING: LULUS")
        print("Laporan:", REPORT)
        print("Migrasi dan pengujian check-in belum dijalankan oleh alat ini.")
    except (OSError, ValueError, KeyError, TypeError, AttributeError, IndexError,
            RuntimeError, GetPassWarning, httpx.HTTPError) as error:
        code = str(error) if type(error) is RuntimeError and re.fullmatch(r"[A-Z_]+", str(error)) else "STAGING_AUTH_VERIFICATION_FAILED"
        print("Kode pemeriksaan:", code)
        print("PENGUJIAN DIHENTIKAN. Periksa publishable key staging, password tester dan akses Data API/profil.")
        print("Tidak ada migrasi/check-in dijalankan. Jangan kirim key, password, token, atau respons mentah.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nPengujian dihentikan. Tidak ada migrasi/check-in dijalankan.")
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
