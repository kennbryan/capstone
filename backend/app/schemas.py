"""Explicit API and upstream contracts; never return the full Auth user."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, StrictBool


class MeResponse(BaseModel):
    id: UUID
    displayName: str
    email: str


class ErrorResponse(BaseModel):
    error: str
    message: str


class AuthUser(BaseModel):
    id: UUID
    email_confirmed_at: datetime | None = None
    is_anonymous: StrictBool = False


class WebsiteProfile(BaseModel):
    id: UUID
    full_name: str = Field(min_length=1)
    email: str = Field(min_length=1)
    role: str
    is_active: StrictBool
