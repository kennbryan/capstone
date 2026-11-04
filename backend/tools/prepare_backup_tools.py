"""Download portable clients from upstreams. No installation, credentials or DB access."""

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

import certifi
import httpx

ROOT = Path(__file__).resolve().parents[1] / ".backup-tools"
PG_URL = "https://get.enterprisedb.com/postgresql/postgresql-17.11-5-windows-x64-binaries.zip"
AGE_URL = "https://github.com/FiloSottile/age/releases/download/v1.3.2/age-v1.3.2-windows-amd64.zip"
AGE_SHA256 = "f48d8f8f9ebe903ab5027ed067652f2cc1db94bc206976430133b905dcd8e8c7"
CLIENTS = {"pg_dump.exe", "pg_dumpall.exe", "pg_restore.exe", "psql.exe"}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def download(client, url, destination, expected=None):
    if not destination.exists():
        # Never treat a partial download as a complete package on the next run.
        partial = destination.with_suffix(destination.suffix + ".partial")
        with client.stream("GET", url) as response:
            response.raise_for_status()
            total = int(response.headers.get("content-length", 0))
            size, last = 0, 0
            with partial.open("wb") as output:
                for chunk in response.iter_bytes(1024 * 1024):
                    output.write(chunk)
                    size += len(chunk)
                    if size - last >= 50 * 1024 * 1024:
                        print("Download", destination.name, size // (1024 * 1024), "MiB", flush=True)
                        last = size
            if total and size != total:
                raise RuntimeError("Incomplete tool download")
        partial.replace(destination)
    result = digest(destination)
    if expected and result != expected:
        raise RuntimeError("Upstream package digest mismatch")
    return result


def main():
    if os.name != "nt":
        raise SystemExit("This portable package is for Windows x64 only.")
    ROOT.mkdir(exist_ok=True)
    with httpx.Client(timeout=60, follow_redirects=True, trust_env=False) as client:
        pg_zip, age_zip = ROOT / "postgresql-17.11.zip", ROOT / "age-1.3.2.zip"
        pg_hash = download(client, PG_URL, pg_zip)
        age_hash = download(client, AGE_URL, age_zip, AGE_SHA256)
    selected = []
    with zipfile.ZipFile(pg_zip) as archive:
        for item in archive.infolist():
            path = PurePosixPath(item.filename)
            if path.parent.as_posix() == "pgsql/bin" and (path.name in CLIENTS or path.suffix.lower() == ".dll"):
                target = ROOT / "pgsql" / "bin" / path.name
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(item) as source, target.open("wb") as output:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)
                selected.append(target)
    with zipfile.ZipFile(age_zip) as archive:
        candidates = [item for item in archive.infolist() if PurePosixPath(item.filename).name == "age.exe"]
        if len(candidates) != 1:
            raise RuntimeError("Unexpected age package layout")
        target = ROOT / "age.exe"
        target.write_bytes(archive.read(candidates[0]))
        selected.append(target)
    versions = {}
    for name in sorted(CLIENTS):
        path = ROOT / "pgsql" / "bin" / name
        result = subprocess.run([str(path), "--version"], capture_output=True, check=True,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        version = result.stdout.decode("utf-8").strip()
        if "(PostgreSQL) 17.11" not in version:
            raise RuntimeError("Unexpected PostgreSQL client version")
        versions[name] = version
    result = subprocess.run([str(ROOT / "age.exe"), "--version"], capture_output=True,
                            check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    versions["age.exe"] = result.stdout.decode("utf-8").strip()
    if versions["age.exe"].removeprefix("v") != "1.3.2":
        raise RuntimeError("Unexpected age version")
    manifest = {
        "sources": {"postgresql": PG_URL, "age": AGE_URL},
        "package_sha256": {"postgresql": pg_hash, "age": age_hash},
        "upstream_age_digest_verified": True,
        "postgresql_download_tls_verified": True,
        "postgresql_independent_vendor_digest_verified": False,
        "versions": versions,
        "files": {str(path.relative_to(ROOT)).replace("\\", "/"): digest(path) for path in selected},
        "ca_bundle_source": certifi.where(),
    }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Portable PostgreSQL 17.11 and age 1.3.2 ready. No database connection performed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, httpx.HTTPError, subprocess.SubprocessError, zipfile.BadZipFile):
        raise SystemExit("Tool preparation failed. No database access or migration performed.") from None
