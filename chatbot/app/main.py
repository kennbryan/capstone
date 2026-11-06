import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import delete, select

from .config import DATA_DIR, RUNTIME_DIR, get_settings
from .db import ChatSession, Message, UserMemory, make_engine, make_session_factory
from .llm import LLMClient
from .memory import update_memory
from .mobile_api import router as mobile_router
from .pipeline import ChatPipeline, SessionNotFound
from .rag.retriever import Retriever
from .resources import load_resources
from .schemas import ChatRequest, ChatResponse, MemoryOut, MessageOut, SessionOut, SummaryDraftResponse
from .supabase_auth import SupabaseVerifier

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    if not getattr(app.state, "pipeline", None):  # test dapat menyuntikkan pipeline sendiri
        llm = LLMClient(settings)
        retriever = Retriever(DATA_DIR / "knowledge_base", RUNTIME_DIR)
        await retriever.build(llm)
        session_factory = make_session_factory(make_engine())
        app.state.pipeline = ChatPipeline(settings, llm, retriever, load_resources(DATA_DIR), session_factory)
    http = None
    if not getattr(app.state, "verifier", None) and settings.supabase_url and settings.supabase_publishable_key:
        # Tanpa redirect dan tanpa proxy dari environment; token pengguna tidak disimpan di client.
        http = httpx.AsyncClient(timeout=5.0, follow_redirects=False, trust_env=False)
        app.state.verifier = SupabaseVerifier(settings.supabase_url, settings.supabase_publishable_key, http)
    yield
    if http is not None:
        await http.aclose()


app = FastAPI(
    title="Chatbot Hibrida MSU",
    description="Layanan AI pendamping well-being: triase risiko, RAG, memori personal, dan draft ringkasan.",
    version="0.1.0",
    lifespan=lifespan,
)

# Hanya dibutuhkan saat aplikasi Flutter dijalankan sebagai web (flutter run -d chrome).
if origins := [o.strip() for o in get_settings().cors_origins.split(",") if o.strip()]:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["*"], allow_headers=["*"])

app.include_router(mobile_router)


def pipeline() -> ChatPipeline:
    return app.state.pipeline


def require_service_key(x_service_key: str | None = Header(None)):
    expected = get_settings().service_api_key
    if expected and x_service_key != expected:
        raise HTTPException(401, "service key tidak valid")


api = [Depends(require_service_key)]


@app.get("/health")
def health(p: ChatPipeline = Depends(pipeline)):
    return {
        "status": "ok",
        "chat_model": p.settings.chat_model,
        "kb_documents": len(p.retriever.documents),
        "kb_chunks": len(p.retriever.chunks),
        "activities": len(p.resources.activities),
    }


@app.post("/v1/chat", response_model=ChatResponse, dependencies=api)
async def chat(req: ChatRequest, background: BackgroundTasks, p: ChatPipeline = Depends(pipeline)):
    try:
        response, refresh_memory = await p.handle(req)
    except SessionNotFound:
        raise HTTPException(404, "sesi tidak ditemukan")
    if refresh_memory:
        background.add_task(update_memory, p.llm, p.db, req.user_id, response.session_id)
    return response


@app.get("/v1/users/{user_id}/sessions", response_model=list[SessionOut], dependencies=api)
def list_sessions(user_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        return db.scalars(
            select(ChatSession).where(ChatSession.user_id == user_id).order_by(ChatSession.updated_at.desc())
        ).all()


@app.get("/v1/users/{user_id}/sessions/{session_id}/messages", response_model=list[MessageOut], dependencies=api)
def list_messages(user_id: str, session_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        chat = db.get(ChatSession, session_id)
        if chat is None or chat.user_id != user_id:
            raise HTTPException(404, "sesi tidak ditemukan")
        return db.scalars(select(Message).where(Message.session_id == session_id).order_by(Message.created_at)).all()


@app.delete("/v1/users/{user_id}/sessions/{session_id}", status_code=204, dependencies=api)
def delete_session(user_id: str, session_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        chat = db.get(ChatSession, session_id)
        if chat is None or chat.user_id != user_id:
            raise HTTPException(404, "sesi tidak ditemukan")
        db.delete(chat)
        db.commit()


@app.post("/v1/users/{user_id}/sessions/{session_id}/summary-draft",
          response_model=SummaryDraftResponse, dependencies=api)
async def summary_draft(user_id: str, session_id: str, p: ChatPipeline = Depends(pipeline)):
    try:
        return await p.summary_draft(user_id, session_id)
    except SessionNotFound:
        raise HTTPException(404, "sesi tidak ditemukan")


@app.get("/v1/users/{user_id}/memory", response_model=list[MemoryOut], dependencies=api)
def list_memory(user_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        return db.scalars(select(UserMemory).where(UserMemory.user_id == user_id)).all()


@app.delete("/v1/users/{user_id}/memory/{memory_id}", status_code=204, dependencies=api)
def delete_memory(user_id: str, memory_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        result = db.execute(delete(UserMemory).where(UserMemory.id == memory_id, UserMemory.user_id == user_id))
        db.commit()
        if result.rowcount == 0:
            raise HTTPException(404, "memori tidak ditemukan")


@app.delete("/v1/users/{user_id}/memory", status_code=204, dependencies=api)
def clear_memory(user_id: str, p: ChatPipeline = Depends(pipeline)):
    with p.db() as db:
        db.execute(delete(UserMemory).where(UserMemory.user_id == user_id))
        db.commit()


@app.get("/v1/activities", dependencies=api)
def activities(p: ChatPipeline = Depends(pipeline)):
    return list(p.resources.activities.values())


@app.get("/v1/help-resources", dependencies=api)
def help_resources(p: ChatPipeline = Depends(pipeline)):
    return p.resources.help_resources


@app.get("/v1/knowledge-base", dependencies=api)
def knowledge_base(p: ChatPipeline = Depends(pipeline)):
    return [
        {"id": d.id, "title": d.title, "topic": d.topic, "source_name": d.source_name,
         "source_url": d.source_url, "version": d.version, "updated": d.updated}
        for d in p.retriever.documents.values()
    ]

