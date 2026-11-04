"""Two-account live check-in test pinned to staging, using the actual FastAPI routes.

Normal mode writes synthetic check-ins; --verify-only reads existing final values.
Both modes create Auth sessions. No .env, source requests, migrations, profile
changes, privileged key, automatic retry, or listening server is used.
"""

import argparse
import asyncio
from contextlib import asynccontextmanager
from datetime import date, datetime, timezone
from getpass import GetPassWarning, getpass
import json
import sys
from urllib.parse import urlsplit
import warnings

import httpx

from app.config import BACKEND_DIR, Settings
from app.main import create_app
from tools import verify_checkins
from tools.verify_staging_auth import BASE, TARGET


class RoutedClient:
    """Synchronous interface to ASGI and a single allowed upstream; never localhost HTTP."""

    def __init__(self, runner, backend, upstream):
        self.runner, self.backend, self.upstream = runner, backend, upstream

    def request(self, method, url, **kwargs):
        if url.startswith(verify_checkins.BACKEND + "/"):
            destination, url = self.backend, url.removeprefix(verify_checkins.BACKEND)
        else:
            parsed = urlsplit(url)
            allowed = {("POST", "/auth/v1/token"), ("GET", "/rest/v1/checkins"),
                       ("POST", "/rest/v1/checkins")}
            if (parsed.scheme != "https" or parsed.netloc != f"{TARGET}.supabase.co"
                    or parsed.query or parsed.fragment or (method, parsed.path) not in allowed):
                raise RuntimeError("STAGING_DESTINATION_REJECTED")
            destination = self.upstream
        return self.runner.run(destination.request(method, url, **kwargs))

    def get(self, url, **kwargs):
        return self.request("GET", url, **kwargs)

    def post(self, url, **kwargs):
        return self.request("POST", url, **kwargs)


def run(key, day, verify_only=False, *, transport=None):
    if date.fromisoformat(day).isoformat() != day:
        raise RuntimeError("TEST_DATE_MUST_BE_YYYY_MM_DD")
    configured = Settings(_env_file=None, supabase_url=BASE, supabase_publishable_key=key)
    key = configured.supabase_publishable_key.get_secret_value()
    application = create_app(configured, transport=transport)

    @asynccontextmanager
    async def clients():
        async with application.router.lifespan_context(application):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=application),
                                         base_url="http://in-process", trust_env=False) as backend:
                async with httpx.AsyncClient(transport=transport, timeout=20,
                                             follow_redirects=False, trust_env=False) as upstream:
                    yield backend, upstream

    with asyncio.Runner() as runner:
        context = clients()
        backend, upstream = runner.run(context.__aenter__())
        try:
            verify_checkins.run(RoutedClient(runner, backend, upstream), BASE, key, day,
                                verify_only, restart_hint=False)
        finally:
            runner.run(context.__aexit__(None, None, None))
    return {
        "status": "STAGING_CHECKINS_READBACK_VERIFIED" if verify_only else "STAGING_CHECKINS_WRITE_AND_ISOLATION_VERIFIED",
        "completed_utc": datetime.now(timezone.utc).isoformat(),
        "target_project_ref": TARGET, "test_date": day, "tester_count": 2,
        "mode": "verify-only" if verify_only else "write-and-verify",
        "backend_route_execution": "fresh in-process FastAPI ASGI; no HTTP listener tested",
        "source_requests_made": False, "env_file_read_or_changed": False,
        "auth_sessions_created": True, "migration_applied_by_tool": False,
        "own_history_and_direct_data_api_match": True,
        "cross_user_read_hidden_both_directions": True,
        "cross_user_write_rejected_both_directions_this_run": not verify_only,
        "upsert_stable_id_and_note_clear_verified_this_run": not verify_only,
        "invalid_mood_and_body_user_id_rejected_this_run": not verify_only,
        "existing_test_date_overwritten": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, help="Tanggal uji YYYY-MM-DD kosong pada kedua akun")
    parser.add_argument("--verify-only", action="store_true", help="Baca hasil akhir pada proses baru, tanpa menulis check-in")
    args = parser.parse_args()
    try:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            raise RuntimeError("PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
        warnings.simplefilter("error", GetPassWarning)
        if date.fromisoformat(args.date).isoformat() != args.date:
            raise RuntimeError("TEST_DATE_MUST_BE_YYYY_MM_DD")
        print("Target STAGING:", TARGET)
        print("Tanggal uji:", args.date)
        print("Mode:", "BACA ULANG, tanpa menulis check-in" if args.verify_only else "TULIS DAN UJI dua check-in sintetis")
        print("Menggunakan kode FastAPI dalam proses; .env dan server port 8001 tidak digunakan.")
        print("Tidak ada migrasi/perubahan profil. Login membuat sesi Auth staging.")
        report = run(getpass("Publishable key project STAGING (tersembunyi): "), args.date, args.verify_only)
        name = "staging-checkins-readback.json" if args.verify_only else "staging-checkins-verification.json"
        path = BACKEND_DIR / "docs/evidence" / name
        try:
            path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        except OSError:
            print("PENGUJIAN LULUS, tetapi laporan lokal gagal ditulis. Jangan mengulang mode tulis.")
            raise SystemExit(1) from None
        print("PENGUJIAN CHECK-IN STAGING: LULUS")
        print("Laporan:", path)
        if not args.verify_only:
            print("Berikutnya baca ulang dari proses baru dengan --verify-only dan tanggal yang sama.")
    except SystemExit:
        raise
    except (OSError, ValueError, KeyError, TypeError, AttributeError, IndexError,
            RuntimeError, GetPassWarning, httpx.HTTPError):
        print("PENGUJIAN DIHENTIKAN. Periksa key staging, koneksi, password dan konfigurasi Data API.")
        print("Jika sudah ada POST, hasil penulisan bisa belum diketahui. Jangan mengulang otomatis.")
        print("Jangan kirim key, password, token, catatan atau respons mentah.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nPengujian dihentikan. Jika sudah ada penulisan, periksa hasil sebelum mengulang.")
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
