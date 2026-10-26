"""Memori personalisasi per pengguna dan ringkasan sesi bergulir."""

import logging
from typing import Literal

from pydantic import BaseModel, Field
from sqlalchemy import select

from .db import ChatSession, Message, UserMemory
from .llm import LLMClient
from .prompts import MEMORY_SYSTEM

log = logging.getLogger(__name__)

MAX_MEMORIES = 25
Category = Literal["identitas", "preferensi", "tujuan", "pemicu", "yang_membantu"]


class MemoryOp(BaseModel):
    op: Literal["add", "update", "delete"]
    memory_id: str | None = Field(None, description="Wajib untuk update dan delete")
    category: Category
    content: str = Field(description="Satu kalimat pendek, kosong untuk delete")


class MemoryUpdate(BaseModel):
    operations: list[MemoryOp]
    session_summary: str


def format_memories(memories: list[UserMemory]) -> str:
    if not memories:
        return "(belum ada)"
    return "\n".join(f"- [{m.category}] {m.content}" for m in memories)


async def update_memory(llm: LLMClient, session_factory, user_id: str, session_id: str) -> None:
    with session_factory() as db:
        memories = db.scalars(select(UserMemory).where(UserMemory.user_id == user_id)).all()
        chat = db.get(ChatSession, session_id)
        recent = db.scalars(
            select(Message)
            .where(Message.session_id == session_id)
            .order_by(Message.created_at.desc())
            .limit(12)
        ).all()[::-1]

        existing = "\n".join(f"- id={m.id} [{m.category}] {m.content}" for m in memories) or "(kosong)"
        transcript = "\n".join(
            f"{'Pengguna' if m.role == 'user' else 'Chatbot'}: {m.content}"
            for m in recent
            if m.route != "crisis"  # template krisis tidak perlu diringkas ulang
        )
        prompt = (
            f"Memori yang sudah ada:\n{existing}\n\n"
            f"Ringkasan sesi sebelumnya:\n{chat.summary or '(belum ada)'}\n\n"
            f"Percakapan terbaru:\n{transcript}"
        )
        try:
            result = await llm.structured(
                MemoryUpdate,
                MEMORY_SYSTEM,
                [{"role": "user", "content": prompt}],
                model=llm.settings.utility_model,
                reasoning_effort=llm.settings.utility_reasoning_effort,
            )
        except Exception as exc:
            log.warning("ekstraksi memori gagal: %s", exc)
            return

        by_id = {m.id: m for m in memories}
        count = len(memories)
        for op in result.operations:
            target = by_id.get(op.memory_id or "")
            if op.op == "add" and op.content.strip() and count < MAX_MEMORIES:
                db.add(UserMemory(user_id=user_id, category=op.category, content=op.content.strip(),
                                  source_session_id=session_id))
                count += 1
            elif op.op == "update" and target and op.content.strip():
                target.category, target.content = op.category, op.content.strip()
            elif op.op == "delete" and target:
                db.delete(target)
                count -= 1
        chat.summary = result.session_summary.strip()
        db.commit()
