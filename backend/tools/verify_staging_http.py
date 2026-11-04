"""Read /me and existing test check-ins through the staging HTTP server on port 8002.

Only Auth login POST is allowed. No check-in/profile writes, .env reads or migrations.
"""

import argparse
from datetime import date, datetime, timezone
from getpass import GetPassWarning, getpass
import json
import sys
import warnings

import httpx

from app.config import BACKEND_DIR, Settings
from tools import verify_checkins
from tools.verify_staging_auth import BASE, TARGET, ACCOUNTS

HTTP_BACKEND = "http://127.0.0.1:8002"


class ReadClient:
    def __init__(self, client):
        self.client = client

    def get(self, url, **kwargs):
        if url == verify_checkins.BACKEND + "/checkins":
            url = HTTP_BACKEND + "/checkins"
        elif url != BASE + "/rest/v1/checkins":
            raise RuntimeError("HTTP_TEST_DESTINATION_REJECTED")
        return self.client.get(url, **kwargs)

    def post(self, url, **kwargs):
        if url != BASE + "/auth/v1/token":
            raise RuntimeError("HTTP_TEST_WRITES_FORBIDDEN")
        result = self.client.post(url, **kwargs)
        if result.status_code == 200:
            session = result.json()
            email = kwargs["json"]["email"]
            label = dict(ACCOUNTS)[email]
            response = self.client.get(HTTP_BACKEND + "/me", headers={
                "Authorization": "Bearer " + session["access_token"],
            })
            print("HTTP GET /me " + label + ": HTTP", response.status_code)
            verify_checkins.require(response.status_code == 200, "Profil melalui server HTTP belum berhasil.")
            verify_checkins.require(response.json() == {
                "id": session["user"]["id"], "displayName": label, "email": email,
            }, "Kontrak profil HTTP tidak sesuai akun staging.")
        return result


def run(key, day, *, transport=None):
    if date.fromisoformat(day).isoformat() != day:
        raise RuntimeError("TEST_DATE_MUST_BE_YYYY_MM_DD")
    settings = Settings(_env_file=None, supabase_url=BASE, supabase_publishable_key=key)
    with httpx.Client(timeout=20, trust_env=False, follow_redirects=False, transport=transport) as client:
        response = client.get(HTTP_BACKEND + "/me")
        verify_checkins.require(response.status_code == 401, "Server HTTP harus menolak /me tanpa token.")
        print("HTTP GET /me tanpa token: HTTP 401 — LULUS")
        verify_checkins.run(ReadClient(client), BASE, settings.supabase_publishable_key.get_secret_value(),
                            day, True, restart_hint=False)
    return {
        "status": "STAGING_HTTP_ME_AND_CHECKINS_READBACK_VERIFIED",
        "completed_utc": datetime.now(timezone.utc).isoformat(),
        "target_project_ref": TARGET, "backend_url": HTTP_BACKEND, "test_date": day,
        "tester_count": 2, "authenticated_me_contract_verified": True,
        "missing_and_false_token_rejection_verified": True,
        "http_history_matches_direct_data_api": True,
        "direct_cross_user_reads_hidden_both_directions": True,
        "checkin_writes_performed": False, "auth_sessions_created": True,
        "source_requests_made_by_tool": False, "env_file_read_or_changed": False,
        "flutter_integration_tested": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, help="Tanggal data uji yang sudah lulus pengujian simpan")
    args = parser.parse_args()
    try:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            raise RuntimeError("PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
        warnings.simplefilter("error", GetPassWarning)
        if date.fromisoformat(args.date).isoformat() != args.date:
            raise RuntimeError("TEST_DATE_MUST_BE_YYYY_MM_DD")
        print("Target STAGING:", TARGET)
        print("Server HTTP:", HTTP_BACKEND)
        print("Baca /me dan check-in yang sudah tersimpan. Login membuat sesi Auth staging.")
        report = run(getpass("Publishable key project STAGING (tersembunyi): "), args.date)
        path = BACKEND_DIR / "docs/evidence/staging-http-verification.json"
        path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("PENGUJIAN HTTP STAGING: LULUS")
        print("Laporan:", path)
    except (ValueError, RuntimeError, OSError, KeyError, TypeError, AttributeError,
            IndexError, GetPassWarning, httpx.HTTPError):
        print("PENGUJIAN DIHENTIKAN. Pastikan tools.serve_staging berjalan di port 8002,")
        print("key/password staging benar dan data uji tersedia. Tidak ada check-in ditulis.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nPengujian dihentikan. Tidak ada check-in ditulis.")
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
