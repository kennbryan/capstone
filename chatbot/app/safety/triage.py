"""Triase berlapis: aturan + OpenAI Moderation + classifier LLM.

Keputusan akhir mengikuti prinsip fail-safe:
- Bila classifier LLM gagal, level dari aturan dan moderation tetap dipakai.
- Classifier boleh menurunkan temuan aturan level high (misalnya hiperbola
  "pengen mati aja tugasnya numpuk") tetapi tidak di bawah moderate,
  sehingga pengguna tetap mendapat pertanyaan keamanan dan info bantuan.
"""

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Literal

from pydantic import BaseModel, Field

from ..llm import LLMClient
from ..prompts import TRIAGE_SYSTEM
from .lexicon import level_max, scan

log = logging.getLogger(__name__)

Intent = Literal[
    "greeting",
    "emotional_support",
    "info_question",
    "activity_request",
    "psychologist_request",
    "report_request",
    "medical_request",
    "concern_for_other",
    "out_of_scope",
]


class TriageOutput(BaseModel):
    risk_level: Literal["none", "low", "moderate", "high"]
    subject: Literal["self", "other", "general"] = Field(
        description="Siapa yang berisiko: pengguna sendiri, orang lain, atau pertanyaan umum"
    )
    intent: Intent
    rationale: str = Field(description="Alasan singkat, maksimal 20 kata, tanpa mengutip pesan")


@dataclass
class TriageResult:
    level: str
    intent: str
    subject: str
    signals: dict = field(default_factory=dict)


# Ambang skor moderation yang dianggap sinyal risiko tinggi
_MOD_HIGH = {"self-harm/intent": 0.5, "self-harm/instructions": 0.5, "self-harm": 0.7}
_MOD_MODERATE = {"self-harm": 0.3, "self-harm/intent": 0.25}


def _moderation_level(mod: dict | None) -> str:
    if not mod:
        return "none"
    scores = mod.get("scores", {})
    if any(scores.get(k, 0) >= v for k, v in _MOD_HIGH.items()):
        return "high"
    if any(scores.get(k, 0) >= v for k, v in _MOD_MODERATE.items()):
        return "moderate"
    return "none"


def combine(rule_level: str, mod_level: str, llm: TriageOutput | None) -> tuple[str, str, str]:
    """Mengembalikan (level, intent, subject)."""
    if llm is None:
        return level_max(rule_level, mod_level), "emotional_support", "self"

    level = level_max(llm.risk_level, mod_level)
    if rule_level == "high":
        floor = "moderate" if llm.subject != "general" else "low"
        level = level_max(level, floor)
    elif rule_level == "moderate" and llm.subject == "self":
        level = level_max(level, "low")
    return level, llm.intent, llm.subject


async def triage(llm: LLMClient, message: str, recent: list[dict], utility_model: str) -> TriageResult:
    rules = scan(message)

    async def run_moderation():
        try:
            return await llm.moderate(message)
        except Exception as exc:  # moderation bersifat tambahan
            log.warning("moderation gagal: %s", exc)
            return None

    async def run_classifier():
        context = "\n".join(f"{m['role']}: {m['content']}" for m in recent[-4:])
        prompt = f"Konteks percakapan sebelumnya:\n{context or '(belum ada)'}\n\nPesan terbaru pengguna:\n{message}"
        try:
            return await llm.structured(
                TriageOutput,
                TRIAGE_SYSTEM,
                [{"role": "user", "content": prompt}],
                model=utility_model,
                reasoning_effort=llm.settings.utility_reasoning_effort,
            )
        except Exception as exc:
            log.warning("classifier triase gagal: %s", exc)
            return None

    mod, cls = await asyncio.gather(run_moderation(), run_classifier())
    mod_level = _moderation_level(mod)
    level, intent, subject = combine(rules.level, mod_level, cls)

    signals = {
        "rules": {"level": rules.level, "categories": rules.categories},
        "moderation": {"level": mod_level, "available": mod is not None},
        "classifier": cls.model_dump(exclude={"rationale"}) if cls else None,
    }
    return TriageResult(level=level, intent=intent, subject=subject, signals=signals)
