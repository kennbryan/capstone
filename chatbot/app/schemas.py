from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=64, description="ID pengguna dari backend utama")
    message: str = Field(min_length=1, max_length=4000)
    session_id: str | None = Field(None, description="Kosongkan untuk memulai sesi baru")
    display_name: str | None = Field(None, max_length=60, description="Nama panggilan opsional")


class Source(BaseModel):
    id: str
    title: str
    source_name: str
    url: str


ActionType = Literal[
    "open_activity",
    "open_psychologist_chat",
    "prepare_summary",
    "call_phone",
    "open_url",
    "open_report",
]


class Action(BaseModel):
    type: ActionType
    label: str
    payload: dict = {}


class ChatResponse(BaseModel):
    session_id: str
    message_id: str
    reply: str
    risk_level: Literal["none", "low", "moderate", "high"]
    route: str
    sources: list[Source] = []
    actions: list[Action] = []
    help_resources: list[dict] = []
    latency_ms: int


class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    risk_level: str | None
    route: str | None
    sources: list | None
    actions: list | None
    created_at: datetime


class SessionOut(BaseModel):
    id: str
    title: str | None
    max_risk_level: str
    created_at: datetime
    updated_at: datetime


class MemoryOut(BaseModel):
    id: str
    category: str
    content: str
    updated_at: datetime


class SummaryDraft(BaseModel):
    """Draft ringkasan untuk psikolog. Tidak pernah dikirim otomatis."""

    ringkasan: str = Field(description="Ringkasan dari sudut pandang pengguna, maksimal 150 kata")
    topik_utama: list[str] = Field(description="2 sampai 4 topik utama")
    yang_sudah_dicoba: list[str] = Field(description="Hal yang sudah dicoba pengguna, boleh kosong")
    harapan: str = Field(description="Apa yang ingin dibahas dengan psikolog, kosong jika tidak disebut")


class SummaryDraftResponse(BaseModel):
    session_id: str
    status: Literal["draft"] = "draft"
    draft: SummaryDraft
    note: str = "Draft ini belum dikirim. Periksa dan ubah isinya, lalu kirim hanya jika kamu setuju."
