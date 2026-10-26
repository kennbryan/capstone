"""Orkestrasi chatbot hibrida: triase -> rute -> retrieval -> generasi -> pemeriksaan keluaran."""

import asyncio
import logging
import time

from pydantic import BaseModel, Field
from sqlalchemy import func, select

from .config import Settings
from .db import ChatSession, Message, SafetyEvent, UserMemory
from .llm import LLMClient
from .memory import format_memories
from .prompts import (
    CONCERN_FOR_OTHER_ADDENDUM,
    GUARD_RETRY,
    MEDICAL_ADDENDUM,
    MODERATE_RISK_ADDENDUM,
    SUMMARY_DRAFT_SYSTEM,
    chat_system,
)
from .rag.retriever import Hit, Retriever
from .resources import Resources
from .safety import output_guard
from .safety.lexicon import LEVELS, level_max
from .safety.triage import TriageResult, triage
from .schemas import Action, ChatRequest, ChatResponse, Source, SummaryDraft, SummaryDraftResponse

log = logging.getLogger(__name__)


class ChatOutput(BaseModel):
    reply: str
    used_source_ids: list[str] = Field(description="id materi rujukan yang dipakai")
    suggested_activity_ids: list[str] = Field(description="0-2 id aktivitas dari katalog")
    suggest_psychologist: bool


class SessionNotFound(Exception):
    pass


class ChatPipeline:
    def __init__(self, settings: Settings, llm: LLMClient, retriever: Retriever,
                 resources: Resources, session_factory):
        self.settings = settings
        self.llm = llm
        self.retriever = retriever
        self.resources = resources
        self.db = session_factory

    # ---------- tahap persiapan ----------

    def _load_session(self, db, req: ChatRequest) -> ChatSession:
        if req.session_id:
            chat = db.get(ChatSession, req.session_id)
            # objek milik pengguna lain diperlakukan sama dengan tidak ada
            if chat is None or chat.user_id != req.user_id:
                raise SessionNotFound(req.session_id)
            return chat
        chat = ChatSession(user_id=req.user_id, title=req.message[:60])
        db.add(chat)
        db.flush()
        return chat

    def _history(self, db, session_id: str) -> list[dict]:
        rows = db.scalars(
            select(Message)
            .where(Message.session_id == session_id)
            .order_by(Message.created_at.desc())
            .limit(self.settings.history_turns * 2)
        ).all()[::-1]
        return [{"role": m.role, "content": m.content} for m in rows]

    async def _embed_query(self, text: str):
        try:
            return (await self.llm.embed([text]))[0]
        except Exception as exc:
            log.warning("embedding query gagal: %s", exc)
            return None

    # ---------- alur utama ----------

    async def handle(self, req: ChatRequest) -> tuple[ChatResponse, bool]:
        """Mengembalikan respons dan penanda apakah memori perlu diperbarui."""
        started = time.perf_counter()
        with self.db() as db:
            chat = self._load_session(db, req)
            history = self._history(db, chat.id)
            user_msg = Message(session_id=chat.id, user_id=req.user_id, role="user", content=req.message)
            db.add(user_msg)
            db.commit()  # pesan pengguna tersimpan walau langkah berikutnya gagal
            session_id, session_risk, session_summary = chat.id, chat.max_risk_level, chat.summary
            memories = db.scalars(select(UserMemory).where(UserMemory.user_id == req.user_id)).all()

        query = req.message
        prev_user = next((m["content"] for m in reversed(history) if m["role"] == "user"), None)
        if prev_user and len(req.message.split()) < 6:
            query = f"{prev_user}\n{req.message}"

        tri, query_vec = await asyncio.gather(
            triage(self.llm, req.message, history, self.settings.utility_model),
            self._embed_query(query),
        )

        if tri.level == "high" and tri.subject == "self":
            reply, route, sources, actions, help_res = self._crisis(tri)
        elif tri.intent == "report_request" and tri.level in ("none", "low"):
            reply = self.resources.crisis_templates["report_request"]
            route, sources, help_res = "report", [], []
            actions = [Action(type="open_report", label="Buka menu Rapor")]
        else:
            reply, route, sources, actions, help_res = await self._generate(
                req, tri, history, query_vec, memories, session_risk, session_summary
            )

        latency = int((time.perf_counter() - started) * 1000)
        with self.db() as db:
            bot_msg = Message(
                session_id=session_id, user_id=req.user_id, role="assistant", content=reply,
                risk_level=tri.level, intent=tri.intent, route=route,
                sources=[s.model_dump() for s in sources], actions=[a.model_dump() for a in actions],
                latency_ms=latency,
            )
            db.add(bot_msg)
            stored_user = db.get(Message, user_msg.id)
            stored_user.risk_level, stored_user.intent = tri.level, tri.intent
            chat = db.get(ChatSession, session_id)
            chat.max_risk_level = level_max(chat.max_risk_level, tri.level)
            if LEVELS.index(tri.level) >= LEVELS.index("moderate"):
                db.add(SafetyEvent(user_id=req.user_id, session_id=session_id, message_id=user_msg.id,
                                   level=tri.level, signals={**tri.signals, "route": route}))
            db.commit()
            user_count = db.scalar(
                select(func.count()).select_from(Message)
                .where(Message.session_id == session_id, Message.role == "user")
            )

        response = ChatResponse(
            session_id=session_id, message_id=bot_msg.id, reply=reply, risk_level=tri.level,
            route=route, sources=sources, actions=actions, help_resources=help_res, latency_ms=latency,
        )
        return response, user_count % self.settings.memory_update_every == 0

    # ---------- rute ----------

    def _help_actions(self) -> list[Action]:
        return [
            Action(type="call_phone", label="Telepon Healing119 (119 ext 8)", payload={"phone": "119", "extension": "8"}),
            Action(type="open_url", label="Chat Healing119.id", payload={"url": "https://www.healing119.id"}),
            Action(type="call_phone", label="Darurat 112", payload={"phone": "112"}),
        ]

    def _crisis(self, tri: TriageResult):
        cats = tri.signals["rules"]["categories"]
        harm_others_only = "harm_others" in cats and not {"suicide", "self_harm"} & set(cats)
        key = "harm_others_high" if harm_others_only else "self_harm_high"
        actions = self._help_actions() + [
            Action(type="open_psychologist_chat", label="Hubungkan ke psikolog MSU"),
        ]
        return self.resources.crisis_templates[key], "crisis", [], actions, self.resources.crisis_help

    def _context_block(self, hits: list[Hit], memories, session_summary, display_name) -> str:
        if hits:
            materials = "\n\n".join(
                f"[{h.document.id}] {h.document.title} > {h.chunk.heading}\n{h.chunk.text}" for h in hits
            )
        else:
            materials = "(tidak ada materi yang relevan; jangan mengarang fakta)"
        parts = [
            f"MATERI RUJUKAN:\n{materials}",
            f"KATALOG AKTIVITAS:\n{self.resources.activity_catalog_text()}",
            f"MEMORI PENGGUNA:\n{format_memories(memories)}",
        ]
        if session_summary:
            parts.append(f"RINGKASAN PERCAKAPAN SEBELUMNYA DI SESI INI:\n{session_summary}")
        if display_name:
            parts.append(f"Nama panggilan pengguna: {display_name}")
        return "\n\n".join(parts)

    async def _generate(self, req, tri: TriageResult, history, query_vec, memories,
                        session_risk, session_summary):
        hits = []
        if query_vec is not None:
            hits = self.retriever.search(query_vec, self.settings.retrieval_top_k, self.settings.retrieval_min_score)

        addenda, route = [], "rag"
        concern_other = tri.intent == "concern_for_other" or (
            tri.subject == "other" and LEVELS.index(tri.level) >= LEVELS.index("moderate")
        )
        if concern_other:
            addenda.append(CONCERN_FOR_OTHER_ADDENDUM)
            route = "concern_for_other"
        elif tri.level in ("moderate", "high") or session_risk == "high":
            # sesi yang pernah masuk rute krisis tetap dalam mode aman
            addenda.append(MODERATE_RISK_ADDENDUM)
            route = "supportive_safety"
        if tri.intent == "medical_request":
            addenda.append(MEDICAL_ADDENDUM)
            route = "medical_boundary" if route == "rag" else route

        system = "\n\n".join([
            chat_system(self.settings.bot_name),
            *addenda,
            self._context_block(hits, memories, session_summary, req.display_name),
        ])
        messages = [*history, {"role": "user", "content": req.message}]

        try:
            out = await self.llm.structured(ChatOutput, system, messages)
            violations = output_guard.check(out.reply)
            if violations:
                log.info("output guard: %s, generate ulang", violations)
                retry_system = system + "\n\n" + GUARD_RETRY.format(reason=", ".join(violations))
                out = await self.llm.structured(ChatOutput, retry_system, messages)
                if output_guard.check(out.reply):
                    out.reply = self.resources.crisis_templates["guard_fallback"]
                    route += "+guard_fallback"
        except Exception as exc:
            log.error("generasi gagal: %s", exc)
            show_help = LEVELS.index(tri.level) >= LEVELS.index("moderate")
            return (self.resources.crisis_templates["llm_unavailable"], "fallback", [],
                    self._help_actions() if show_help else [],
                    self.resources.crisis_help if show_help else [])

        hit_docs = {h.document.id: h.document for h in hits}
        sources = [
            Source(id=d.id, title=d.title, source_name=d.source_name, url=d.source_url)
            for doc_id in dict.fromkeys(out.used_source_ids)
            if (d := hit_docs.get(doc_id))
        ]

        actions: list[Action] = []
        elevated = LEVELS.index(tri.level) >= LEVELS.index("moderate") or concern_other
        if not elevated:
            for act_id in out.suggested_activity_ids[:2]:
                if act := self.resources.activities.get(act_id):
                    actions.append(Action(type="open_activity", label=act["title"], payload={"activity_id": act_id}))
        if out.suggest_psychologist or elevated or tri.intent == "psychologist_request":
            actions.append(Action(type="open_psychologist_chat", label="Chat dengan psikolog"))
            actions.append(Action(type="prepare_summary", label="Siapkan ringkasan untuk psikolog"))
        help_res = []
        if elevated:
            actions = self._help_actions() + actions
            help_res = self.resources.crisis_help
        return out.reply, route, sources, actions, help_res

    # ---------- ringkasan untuk psikolog ----------

    async def summary_draft(self, user_id: str, session_id: str) -> SummaryDraftResponse:
        with self.db() as db:
            chat = db.get(ChatSession, session_id)
            if chat is None or chat.user_id != user_id:
                raise SessionNotFound(session_id)
            rows = db.scalars(
                select(Message).where(Message.session_id == session_id).order_by(Message.created_at)
            ).all()
        transcript = "\n".join(
            f"{'Aku' if m.role == 'user' else 'Chatbot'}: {m.content}" for m in rows[-30:]
        )
        draft = await self.llm.structured(
            SummaryDraft, SUMMARY_DRAFT_SYSTEM, [{"role": "user", "content": transcript}]
        )
        return SummaryDraftResponse(session_id=session_id, draft=draft)
