"""Authenticate and forward one mobile chatbot message to the internal service."""

import asyncio
import json
from contextlib import aclosing
from typing import Literal

import httpx
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, JsonValue, StrictStr, ValidationError, field_validator

from .auth import ApiError, ProfileService
from .config import Settings

CHAT_TIMEOUT_SECONDS = 30.0
MAX_REPLY_BYTES = 256 * 1024


class ChatMessageInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: StrictStr = Field(min_length=1, max_length=4000)
    conversationId: StrictStr | None = Field(None, min_length=1, max_length=64)
    displayName: StrictStr | None = Field(None, max_length=60)

    @field_validator("text", "conversationId", "displayName", mode="before")
    @classmethod
    def validate_text(cls, value):
        if isinstance(value, str):
            if "\x00" in value:
                raise ValueError("Invalid text")
            try:
                value.encode("utf-8")
            except UnicodeError:
                raise ValueError("Invalid text") from None
        return value

    @field_validator("text", "conversationId")
    @classmethod
    def reject_blank(cls, value: str | None) -> str | None:
        if value is not None and not value.strip():
            raise ValueError("Must not be blank")
        return value


class ChatSource(BaseModel):
    articleId: str
    title: str
    sourceName: str | None = None
    url: str | None = None


class ChatSuggestion(BaseModel):
    kind: str
    title: str
    id: str | None = None


class ChatAction(BaseModel):
    type: str
    label: str
    payload: dict[str, JsonValue] = Field(default_factory=dict)

    @field_validator("payload")
    @classmethod
    def validate_payload(cls, value: dict[str, JsonValue]) -> dict[str, JsonValue]:
        # Validate nested numbers before sending JSON to Flutter.
        json.dumps(value, allow_nan=False)
        return value


class ChatMessageResponse(BaseModel):
    id: str
    role: Literal["assistant"]
    type: Literal["normal", "crisis"]
    text: str
    createdAt: AwareDatetime
    conversationId: str
    sources: list[ChatSource] = Field(default_factory=list)
    suggestions: list[ChatSuggestion] = Field(default_factory=list)
    actions: list[ChatAction] = Field(default_factory=list)


class ChatGateway:
    def __init__(self, settings: Settings, client: httpx.AsyncClient, profiles: ProfileService):
        self._url = settings.chatbot_base_url
        self._key = settings.chatbot_service_key
        self._client = client
        self._profiles = profiles

    async def send(self, token: str, body: ChatMessageInput) -> ChatMessageResponse:
        profile = await self._profiles.verified_profile(token)
        if profile.role != "PARTICIPANT":
            raise ApiError(403, "FORBIDDEN")
        if self._url is None or self._key is None:
            raise ApiError(503, "CHATBOT_UNAVAILABLE")

        # Construct a new request. The caller's token, headers, and query are
        # never forwarded. The dedicated client does not add stored cookies
        # to this explicit request. displayName is an optional presentation hint.
        try:
            request = httpx.Request(
                "POST",
                f"{self._url.get_secret_value()}/chatbot/messages",
                headers={
                    "X-User-Id": str(profile.id),
                    "X-Service-Key": self._key.get_secret_value(),
                    "Accept": "application/json",
                    "Accept-Encoding": "identity",
                },
                json=body.model_dump(exclude_none=True),
            )
            async with asyncio.timeout(CHAT_TIMEOUT_SECONDS):
                async with aclosing(await self._client.send(request, stream=True)) as response:
                    content_type = response.headers.get("content-type", "").split(";", 1)[0].strip().lower()
                    encoding = response.headers.get("content-encoding", "identity").strip().lower()
                    if response.status_code != 200 or content_type != "application/json" or encoding != "identity":
                        raise ApiError(503, "CHATBOT_UNAVAILABLE")
                    reply = bytearray()
                    async for chunk in response.aiter_bytes():
                        if len(reply) + len(chunk) > MAX_REPLY_BYTES:
                            raise ApiError(503, "CHATBOT_UNAVAILABLE")
                        reply.extend(chunk)
                    return ChatMessageResponse.model_validate_json(reply)
        except (httpx.HTTPError, httpx.InvalidURL, TimeoutError, ValidationError, ValueError, RecursionError):
            # A POST may already have been processed, so never retry here.
            raise ApiError(503, "CHATBOT_UNAVAILABLE") from None
