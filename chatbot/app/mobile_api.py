"""Endpoint untuk aplikasi mobile Flutter (folder lib/ di repo ini).

Bentuk JSON mengikuti kontrak di lib/features/chat/data/sources/chat_sources.dart:
key camelCase, balasan krisis bertipe "crisis", dan saran latihan memakai
`suggestions[].kind` (breathing, release, sounds, article).

Identitas pengguna diambil dari header, bukan dari body:
- `Authorization: Bearer <access token Supabase>` dari login aplikasi; token diverifikasi
  ke Supabase Auth (aktif jika SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY diisi);
- `Authorization: Bearer demo-session-<userId>` untuk akun demo aplikasi
  (aktif jika MOBILE_DEMO_TOKENS=true);
- `X-Service-Key` + `X-User-Id` jika permintaan diteruskan backend utama
  yang sudah memverifikasi token pengguna.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel
from sqlalchemy import delete, select

from .config import get_settings
from .db import ChatSession, UserMemory
from .memory import update_memory
from .pipeline import ChatPipeline, SessionNotFound
from .schemas import ChatRequest
from .supabase_auth import AuthRejected, AuthUnavailable

DEMO_TOKEN_PREFIX = "demo-session-"

# Aktivitas yang sudah punya layar sendiri di aplikasi.
ACTIVITY_SCREENS = {"napas-lambat": "breathing", "melepas-pikiran": "release"}


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class MobileMessageIn(CamelModel):
    text: str = Field(min_length=1, max_length=4000)
    conversation_id: str | None = None
    display_name: str | None = Field(None, max_length=60)


class SourceRefOut(CamelModel):
    article_id: str
    title: str
    source_name: str | None = None
    url: str | None = None


class LearnRefOut(CamelModel):
    kind: str
    title: str
    id: str | None = None


class ActionOut(CamelModel):
    type: str
    label: str
    payload: dict = {}


class MobileMessageOut(CamelModel):
    id: str
    role: str = "assistant"
    type: str = "normal"
    text: str
    created_at: datetime
    conversation_id: str
    sources: list[SourceRefOut] = []
    suggestions: list[LearnRefOut] = []
    actions: list[ActionOut] = []


class SummaryDraftOut(CamelModel):
    conversation_id: str
    status: str = "draft"
    summary: str
    topics: list[str]
    tried: list[str]
    hopes: str
    note: str


class MemoryItemOut(CamelModel):
    id: str
    category: str
    content: str
    updated_at: datetime


def pipeline(request: Request) -> ChatPipeline:
    return request.app.state.pipeline


async def current_user(
    request: Request,
    authorization: str | None = Header(None),
    x_service_key: str | None = Header(None),
    x_user_id: str | None = Header(None),
) -> str:
    settings = get_settings()
    if x_user_id and settings.service_api_key and x_service_key == settings.service_api_key:
        return x_user_id[:64]
    token = (authorization or "").removeprefix("Bearer ").strip()
    if settings.mobile_demo_tokens and token.startswith(DEMO_TOKEN_PREFIX):
        user_id = token.removeprefix(DEMO_TOKEN_PREFIX)
        if 0 < len(user_id) <= 64:
            return user_id
    verifier = getattr(request.app.state, "verifier", None)
    if token and verifier is not None:
        try:
            return await verifier.user_id(token)
        except AuthRejected as e:
            raise HTTPException(e.status_code, "sesi tidak valid atau akun tidak diizinkan",
                                headers={"WWW-Authenticate": "Bearer"} if e.status_code == 401 else None)
        except AuthUnavailable:
            raise HTTPException(503, "verifikasi sesi belum dapat diproses", headers={"Retry-After": "5"})
    raise HTTPException(401, "sesi tidak dikenali", headers={"WWW-Authenticate": "Bearer"})


def _activity_payload(activity: dict) -> dict:
    return {
        "id": activity["id"],
        "title": activity["title"],
        "durationMin": activity.get("duration_min"),
        "description": activity.get("description", ""),
        "steps": activity.get("steps", []),
        "sourceName": activity.get("source_name"),
        "sourceUrl": activity.get("source_url"),
    }


def to_mobile(response, p: ChatPipeline) -> MobileMessageOut:
    suggestions, actions = [], []
    for action in response.actions:
        if action.type == "open_activity":
            activity_id = action.payload.get("activity_id")
            activity = p.resources.activities.get(activity_id)
            if activity is None:
                continue
            if kind := ACTIVITY_SCREENS.get(activity_id):
                suggestions.append(LearnRefOut(kind=kind, title=activity["title"]))
            else:
                actions.append(ActionOut(type="open_activity", label=activity["title"],
                                         payload=_activity_payload(activity)))
        else:
            actions.append(ActionOut(type=action.type, label=action.label, payload=action.payload))
    return MobileMessageOut(
        id=response.message_id,
        type="crisis" if response.route == "crisis" else "normal",
        text=response.reply,
        created_at=datetime.now(timezone.utc),
        conversation_id=response.session_id,
        sources=[
            SourceRefOut(article_id=s.id, title=s.title, source_name=s.source_name, url=s.url)
            for s in response.sources
        ],
        suggestions=suggestions,
        actions=actions,
    )


router = APIRouter(prefix="/chatbot", tags=["mobile"])


@router.post("/messages", response_model=MobileMessageOut)
async def send_message(body: MobileMessageIn, background: BackgroundTasks,
                       user_id: str = Depends(current_user), p: ChatPipeline = Depends(pipeline)):
    req = ChatRequest(user_id=user_id, message=body.text, session_id=body.conversation_id,
                      display_name=body.display_name)
    try:
        response, refresh_memory = await p.handle(req)
    except SessionNotFound:
        # Percakapan lama sudah dihapus atau milik akun lain: mulai percakapan baru.
        response, refresh_memory = await p.handle(req.model_copy(update={"session_id": None}))
    if refresh_memory:
        background.add_task(update_memory, p.llm, p.db, user_id, response.session_id)
    return to_mobile(response, p)


@router.delete("/conversations/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str, user_id: str = Depends(current_user),
                        p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        chat = db.get(ChatSession, conversation_id)
        if chat is None or chat.user_id != user_id:
            raise HTTPException(404, "percakapan tidak ditemukan")
        db.delete(chat)
        db.commit()


@router.post("/conversations/{conversation_id}/summary-draft", response_model=SummaryDraftOut)
async def summary_draft(conversation_id: str, user_id: str = Depends(current_user),
                        p: ChatPipeline = Depends(pipeline)):
    try:
        result = await p.summary_draft(user_id, conversation_id)
    except SessionNotFound:
        raise HTTPException(404, "percakapan tidak ditemukan")
    return SummaryDraftOut(
        conversation_id=conversation_id,
        summary=result.draft.ringkasan,
        topics=result.draft.topik_utama,
        tried=result.draft.yang_sudah_dicoba,
        hopes=result.draft.harapan,
        note=result.note,
    )


@router.get("/memory", response_model=list[MemoryItemOut])
def list_memory(user_id: str = Depends(current_user), p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        rows = db.scalars(
            select(UserMemory).where(UserMemory.user_id == user_id).order_by(UserMemory.updated_at.desc())
        ).all()
        # SQLite menyimpan waktu tanpa zona; nilainya UTC.
        return [MemoryItemOut(id=m.id, category=m.category, content=m.content,
                              updated_at=m.updated_at.replace(tzinfo=m.updated_at.tzinfo or timezone.utc))
                for m in rows]


@router.delete("/memory/{memory_id}", status_code=204)
def delete_memory(memory_id: str, user_id: str = Depends(current_user), p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        result = db.execute(delete(UserMemory).where(UserMemory.id == memory_id, UserMemory.user_id == user_id))
        db.commit()
        if result.rowcount == 0:
            raise HTTPException(404, "memori tidak ditemukan")


@router.delete("/memory", status_code=204)
def clear_memory(user_id: str = Depends(current_user), p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        db.execute(delete(UserMemory).where(UserMemory.user_id == user_id))
        db.commit()
