"""Run the real HTTP backend against the pinned staging project on local port 8002."""

import argparse
from getpass import GetPassWarning, getpass
import sys
import warnings

import uvicorn
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings
from app.main import create_app
from tools.verify_staging_auth import BASE, TARGET


def staging_app(key):
    settings = Settings(_env_file=None, supabase_url=BASE, supabase_publishable_key=key)
    application = create_app(settings)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:7357", "http://127.0.0.1:7357"],
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
        allow_credentials=False,
        expose_headers=["WWW-Authenticate", "Retry-After"],
    )
    return application


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            raise RuntimeError("PRIVATE_INTERACTIVE_TERMINAL_REQUIRED")
        warnings.simplefilter("error", GetPassWarning)
        print("Target STAGING:", TARGET)
        print("Server lokal port 8002; konfigurasi staging hanya disimpan dalam memori proses.")
        application = staging_app(getpass("Publishable key project STAGING (tersembunyi): "))
    except (ValueError, RuntimeError, OSError, GetPassWarning):
        print("SERVER BELUM DIMULAI. Gunakan terminal interaktif dan publishable key staging yang valid.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nServer dibatalkan sebelum dimulai.")
        raise SystemExit(1) from None
    print("Dokumentasi setelah server berjalan: http://127.0.0.1:8002/docs")
    print("Flutter web lokal diizinkan dari localhost:7357 atau 127.0.0.1:7357.")
    print("Biarkan terminal ini terbuka. Ctrl+C untuk menghentikan server staging.")
    uvicorn.run(application, host="127.0.0.1", port=8002, access_log=False,
                proxy_headers=False, log_level="info", reload=False, workers=1)


if __name__ == "__main__":
    main()
