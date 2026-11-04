"""Daily check-in contracts and user-scoped PostgREST persistence."""

import asyncio
import re
from datetime import date
from typing import Annotated
from uuid import UUID

import httpx
from pydantic import (
    BaseModel, BeforeValidator, ConfigDict, Field, StrictInt, StrictStr,
    ValidationError, field_validator, model_validator,
)

from .auth import ApiError, ProfileService, _error_code, unauthorized
from .config import Settings

MAX_RANGE_DAYS = 366
SELECT_COLUMNS = "id,user_id,date,mood,note"


def calendar_date(value: object) -> date:
    # Reject timestamps, epoch numbers, compact dates and silently coerced input.
    if not isinstance(value, str) or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value) is None:
        raise ValueError("Expected a calendar date")
    return date.fromisoformat(value)


CalendarDate = Annotated[date, BeforeValidator(calendar_date)]
Mood = Annotated[StrictInt, Field(ge=1, le=5)]
Note = Annotated[StrictStr, Field(max_length=200)]


class CheckInInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    date: CalendarDate
    mood: Mood
    note: Note | None = None

    @field_validator("note", mode="before")
    @classmethod
    def normalize_note(cls, value):
        if isinstance(value, str):
            # NUL is not valid PostgreSQL text. Reject unpaired JSON surrogates too.
            if "\x00" in value:
                raise ValueError("Invalid note")
            try:
                value.encode("utf-8")
            except UnicodeError:
                raise ValueError("Invalid note") from None
            return value.strip() or None
        return value


class CheckInRange(BaseModel):
    model_config = ConfigDict(extra="forbid")

    from_date: CalendarDate = Field(alias="from")
    to: CalendarDate

    @model_validator(mode="after")
    def bounded_range(self):
        days = (self.to - self.from_date).days + 1
        if not 1 <= days <= MAX_RANGE_DAYS:
            raise ValueError("Expected an inclusive range of 1 to 366 days")
        return self


class StoredCheckIn(BaseModel):
    id: UUID
    user_id: UUID
    date: CalendarDate
    mood: Mood
    note: Note | None = None

    @field_validator("note")
    @classmethod
    def valid_text(cls, value):
        if value is not None:
            if "\x00" in value:
                raise ValueError("Invalid stored note")
            try:
                value.encode("utf-8")
            except UnicodeError:
                raise ValueError("Invalid stored note") from None
        return value


class CheckInResponse(BaseModel):
    id: UUID
    date: date
    mood: Mood
    note: Note | None = None


def checkins_unavailable() -> ApiError:
    return ApiError(503, "CHECKINS_UNAVAILABLE")


class CheckInService:
    def __init__(self, settings: Settings, client: httpx.AsyncClient, profiles: ProfileService):
        self._base_url = settings.supabase_url.get_secret_value()
        self._key = settings.supabase_publishable_key.get_secret_value()
        self._client = client
        self._profiles = profiles

    def _headers(self, token: str, *, write: bool = False) -> dict[str, str]:
        headers = {
            "apikey": self._key,
            "Authorization": f"Bearer {token}",
            "Accept-Profile": "chatbot",
        }
        if write:
            headers.update({
                "Content-Profile": "chatbot",
                "Prefer": "resolution=merge-duplicates,return=representation",
            })
        return headers

    async def _participant(self, token: str) -> UUID:
        profile = await self._profiles.verified_profile(token)
        if profile.role != "PARTICIPANT":
            raise ApiError(403, "FORBIDDEN")
        return profile.id

    @staticmethod
    def _rows(response: httpx.Response) -> list[StoredCheckIn]:
        if response.status_code == 401 and _error_code(response) in {"PGRST301", "PGRST302", "PGRST303"}:
            raise unauthorized()
        if response.status_code not in (200, 201):
            # RLS/configuration failures are never bypassed with an elevated key.
            raise checkins_unavailable()
        body = response.json()
        if not isinstance(body, list) or len(body) > MAX_RANGE_DAYS:
            raise checkins_unavailable()
        return [StoredCheckIn.model_validate(item) for item in body]

    @staticmethod
    def _response(row: StoredCheckIn) -> CheckInResponse:
        return CheckInResponse(id=row.id, date=row.date, mood=row.mood, note=row.note)

    async def list(self, token: str, period: CheckInRange) -> list[CheckInResponse]:
        try:
            async with asyncio.timeout(15):
                user_id = await self._participant(token)
                response = await self._client.get(
                    f"{self._base_url}/rest/v1/checkins",
                    headers=self._headers(token),
                    params=[
                        ("select", SELECT_COLUMNS),
                        ("user_id", f"eq.{user_id}"),
                        ("date", f"gte.{period.from_date.isoformat()}"),
                        ("date", f"lte.{period.to.isoformat()}"),
                        ("order", "date.asc"),
                        ("limit", str(MAX_RANGE_DAYS)),
                    ],
                )
                rows = self._rows(response)
                previous = None
                for row in rows:
                    if (row.user_id != user_id or not period.from_date <= row.date <= period.to
                            or (previous is not None and row.date <= previous)):
                        raise checkins_unavailable()
                    previous = row.date
                return [self._response(row) for row in rows]
        except (httpx.HTTPError, TimeoutError, ValidationError, ValueError):
            raise checkins_unavailable() from None

    async def save(self, token: str, body: CheckInInput) -> CheckInResponse:
        try:
            async with asyncio.timeout(15):
                user_id = await self._participant(token)
                response = await self._client.post(
                    f"{self._base_url}/rest/v1/checkins",
                    headers=self._headers(token, write=True),
                    params={"on_conflict": "user_id,date", "select": SELECT_COLUMNS},
                    json={
                        "user_id": str(user_id),
                        "date": body.date.isoformat(),
                        "mood": body.mood,
                        "note": body.note,
                    },
                )
                rows = self._rows(response)
                if len(rows) != 1:
                    raise checkins_unavailable()
                row = rows[0]
                if (row.user_id != user_id or row.date != body.date
                        or row.mood != body.mood or row.note != body.note):
                    raise checkins_unavailable()
                return self._response(row)
        except (httpx.HTTPError, TimeoutError, ValidationError, ValueError):
            # A write timeout has an unknown commit outcome: do not automatically retry.
            raise checkins_unavailable() from None
