"""Verify Auth on the server and read only the caller's profile through RLS."""

import asyncio
from uuid import UUID

import httpx
from pydantic import ValidationError

from .config import Settings
from .schemas import AuthUser, MeResponse, WebsiteProfile

MESSAGES = {
    "UNAUTHORIZED": "Sesi tidak valid. Silakan masuk kembali.",
    "FORBIDDEN": "Profil akun tidak tersedia atau tidak memiliki akses.",
    "SERVICE_UNAVAILABLE": "Profil belum dapat dimuat. Silakan coba lagi.",
    "CHECKINS_UNAVAILABLE": "Check-in belum dapat diproses. Silakan coba lagi.",
    "CHATBOT_UNAVAILABLE": "Asisten belum dapat dihubungi. Silakan coba lagi.",
    "VALIDATION_ERROR": "Data permintaan tidak valid. Periksa tanggal, mood, dan catatan.",
    "PAYLOAD_TOO_LARGE": "Ukuran permintaan terlalu besar.",
    "UNSUPPORTED_MEDIA_TYPE": "Gunakan Content-Type application/json.",
    "REQUEST_TIMEOUT": "Pengiriman permintaan terlalu lama. Silakan coba lagi.",
}
KNOWN_ROLES = frozenset({"PARTICIPANT", "PSYCHOLOGIST", "SUPERADMIN"})


class ApiError(Exception):
    def __init__(self, status_code: int, code: str):
        self.status_code = status_code
        self.code = code
        super().__init__(code)


def unauthorized() -> ApiError:
    return ApiError(401, "UNAUTHORIZED")


def unavailable() -> ApiError:
    return ApiError(503, "SERVICE_UNAVAILABLE")


def _error_code(response: httpx.Response) -> str | None:
    try:
        body = response.json()
    except ValueError:
        return None
    if not isinstance(body, dict):
        return None
    # Older GoTrue responses use numeric `code` plus string `error_code`.
    for field in ("code", "error_code"):
        if isinstance(body.get(field), str):
            return body[field]
    return None


class ProfileService:
    def __init__(self, settings: Settings, client: httpx.AsyncClient):
        self._base_url = settings.supabase_url.get_secret_value()
        self._key = settings.supabase_publishable_key.get_secret_value()
        self._client = client

    async def me(self, token: str) -> MeResponse:
        profile = await self.verified_profile(token)
        return MeResponse(
            id=profile.id,
            displayName=profile.full_name,
            email=profile.email,
        )

    async def verified_profile(self, token: str) -> WebsiteProfile:
        # Bound the entire two-request operation, not only each network read.
        try:
            async with asyncio.timeout(12):
                headers = {"apikey": self._key, "Authorization": f"Bearer {token}"}
                user = await self._verify_user(headers)
                profile = await self._read_profile(user.id, headers)
                return profile
        except (httpx.HTTPError, TimeoutError, ValidationError, ValueError):
            # Never return/log upstream bodies, tokens, URLs or exception text.
            raise unavailable() from None

    async def _verify_user(self, headers: dict[str, str]) -> AuthUser:
        response = await self._client.get(f"{self._base_url}/auth/v1/user", headers=headers)
        if response.status_code in (401, 403):
            # Gateway errors (e.g. a rejected API key) are configuration/service
            # failures. Only recognized Auth token errors invalidate a session.
            code = _error_code(response)
            if code in {
                "bad_jwt", "session_not_found", "user_not_found",
                "no_authorization", "email_not_confirmed",
            }:
                raise unauthorized()
            if code == "user_banned":
                raise ApiError(403, "FORBIDDEN")
            raise unavailable()
        if response.status_code != 200:
            raise unavailable()
        user = AuthUser.model_validate(response.json())
        if user.is_anonymous or user.email_confirmed_at is None:
            raise unauthorized()
        return user

    async def _read_profile(self, user_id: UUID, headers: dict[str, str]) -> WebsiteProfile:
        response = await self._client.get(
            f"{self._base_url}/rest/v1/users",
            headers={**headers, "Accept-Profile": "public"},
            params={
                "select": "id,full_name,email,role,is_active",
                "id": f"eq.{user_id}",
                "limit": "1",
            },
        )
        if response.status_code == 401:
            code = _error_code(response)
            if code in {"PGRST301", "PGRST302", "PGRST303"}:
                raise unauthorized()
            raise unavailable()
        if response.status_code != 200:
            # Missing Data API/schema/grants must not look like a bad password.
            raise unavailable()
        rows = response.json()
        if rows == []:
            # RLS intentionally makes missing and inactive profiles indistinguishable.
            raise ApiError(403, "FORBIDDEN")
        if not isinstance(rows, list) or len(rows) != 1:
            raise unavailable()
        profile = WebsiteProfile.model_validate(rows[0])
        if profile.id != user_id:
            raise unavailable()
        if not profile.is_active or profile.role not in KNOWN_ROLES:
            raise ApiError(403, "FORBIDDEN")
        return profile
