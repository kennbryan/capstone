"""Verifikasi token login Supabase untuk endpoint /chatbot/*.

Alurnya sama dengan backend utama (backend/app/auth.py): token pengguna dikirim ke
`/auth/v1/user`, lalu profil sendiri dibaca lewat Data API dengan token yang sama
sehingga RLS berlaku. Hanya publishable key yang dipakai; tidak ada secret key.
Identitas tidak pernah diambil dari decode JWT lokal atau dari body request.
"""

import asyncio
import hashlib
import time
from uuid import UUID

import httpx

TOKEN_ERRORS = {"bad_jwt", "session_not_found", "user_not_found", "no_authorization", "email_not_confirmed"}
CHAT_ROLES = {"PARTICIPANT"}
CACHE_TTL = 60.0
CACHE_MAX = 512


class AuthRejected(Exception):
    """Token atau akun tidak boleh memakai chatbot (HTTP 401/403)."""

    def __init__(self, status_code: int):
        self.status_code = status_code
        super().__init__(status_code)


class AuthUnavailable(Exception):
    """Supabase tidak dapat dihubungi atau responsnya tidak sesuai kontrak (HTTP 503)."""


def _error_code(response: httpx.Response) -> str | None:
    try:
        body = response.json()
    except ValueError:
        return None
    if isinstance(body, dict):
        for field in ("code", "error_code"):
            if isinstance(body.get(field), str):
                return body[field]
    return None


class SupabaseVerifier:
    def __init__(self, base_url: str, publishable_key: str, client: httpx.AsyncClient):
        self._base = base_url.rstrip("/")
        self._key = publishable_key
        self._client = client
        self._cache: dict[str, tuple[float, str]] = {}

    async def user_id(self, token: str) -> str:
        """Mengembalikan UUID pengguna yang terverifikasi, atau melempar AuthRejected/AuthUnavailable."""
        cache_key = hashlib.sha256(token.encode()).hexdigest()
        hit = self._cache.get(cache_key)
        if hit and hit[0] > time.monotonic():
            return hit[1]
        try:
            async with asyncio.timeout(12):
                headers = {"apikey": self._key, "Authorization": f"Bearer {token}"}
                uid = await self._verify_user(headers)
                await self._check_profile(uid, headers)
        except (httpx.HTTPError, TimeoutError, ValueError, KeyError, TypeError):
            raise AuthUnavailable from None  # jangan teruskan isi error upstream
        if len(self._cache) >= CACHE_MAX:
            self._cache.clear()
        self._cache[cache_key] = (time.monotonic() + CACHE_TTL, uid)
        return uid

    async def _verify_user(self, headers: dict) -> str:
        r = await self._client.get(f"{self._base}/auth/v1/user", headers=headers)
        if r.status_code in (401, 403):
            code = _error_code(r)
            if code in TOKEN_ERRORS:
                raise AuthRejected(401)
            if code == "user_banned":
                raise AuthRejected(403)
            raise AuthUnavailable  # mis. publishable key ditolak gateway: masalah konfigurasi
        if r.status_code != 200:
            raise AuthUnavailable
        body = r.json()
        if body.get("is_anonymous") or not body.get("email_confirmed_at"):
            raise AuthRejected(401)
        return str(UUID(body["id"]))

    async def _check_profile(self, uid: str, headers: dict) -> None:
        r = await self._client.get(
            f"{self._base}/rest/v1/users",
            headers={**headers, "Accept-Profile": "public"},
            params={"select": "id,role,is_active", "id": f"eq.{uid}", "limit": "1"},
        )
        if r.status_code == 401 and _error_code(r) in {"PGRST301", "PGRST302", "PGRST303"}:
            raise AuthRejected(401)
        if r.status_code != 200:
            raise AuthUnavailable
        rows = r.json()
        if rows == []:
            raise AuthRejected(403)  # RLS: profil tidak ada atau nonaktif
        if not isinstance(rows, list) or len(rows) != 1 or str(UUID(rows[0]["id"])) != uid:
            raise AuthUnavailable
        if not rows[0].get("is_active") or rows[0].get("role") not in CHAT_ROLES:
            raise AuthRejected(403)
