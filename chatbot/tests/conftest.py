import hashlib

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.config import DATA_DIR, Settings
from app.db import make_engine, make_session_factory
from app.memory import MemoryUpdate
from app.pipeline import ChatOutput, ChatPipeline
from app.rag.retriever import Retriever
from app.resources import load_resources
from app.safety.lexicon import scan
from app.safety.triage import TriageOutput
from app.schemas import SummaryDraft


class FakeLLM:
    """Pengganti OpenAI untuk pengujian unit; tidak memanggil jaringan."""

    def __init__(self, settings):
        self.settings = settings
        self.calls: list[str] = []
        self.chat_reply = "Aku dengar kamu. Coba tarik napas pelan dulu ya."
        self.used_sources: list[str] = []
        self.activities: list[str] = ["napas-lambat"]
        self.triage_override: TriageOutput | None = None

    async def structured(self, schema, system, messages, **kwargs):
        self.calls.append(schema.__name__)
        if schema is TriageOutput:
            if self.triage_override:
                return self.triage_override
            level = scan(messages[-1]["content"].split("Pesan terbaru pengguna:\n")[-1]).level
            return TriageOutput(risk_level=level, subject="self", intent="emotional_support", rationale="uji")
        if schema is ChatOutput:
            return ChatOutput(reply=self.chat_reply, used_source_ids=self.used_sources,
                              suggested_activity_ids=self.activities, suggest_psychologist=False)
        if schema is MemoryUpdate:
            return MemoryUpdate(operations=[], session_summary="ringkasan uji")
        if schema is SummaryDraft:
            return SummaryDraft(ringkasan="Aku sedang stres.", topik_utama=["stres"], yang_sudah_dicoba=[], harapan="")
        raise AssertionError(schema)

    async def embed(self, texts):
        vecs = []
        for t in texts:
            seed = int(hashlib.md5(t.encode()).hexdigest()[:8], 16)
            vecs.append(np.random.default_rng(seed).normal(size=32))
        m = np.asarray(vecs, dtype=np.float32)
        return m / np.linalg.norm(m, axis=1, keepdims=True)

    async def moderate(self, text):
        return {"flagged": False, "categories": {}, "scores": {}}


@pytest.fixture
def settings(tmp_path):
    return Settings(openai_api_key="test", database_url=f"sqlite:///{(tmp_path / 't.db').as_posix()}",
                    retrieval_min_score=-1.0, memory_update_every=100)


@pytest.fixture
def fake_llm(settings):
    return FakeLLM(settings)


@pytest.fixture
async def pipeline(settings, fake_llm, tmp_path):
    retriever = Retriever(DATA_DIR / "knowledge_base", tmp_path / "cache")
    await retriever.build(fake_llm)
    factory = make_session_factory(make_engine(settings.database_url))
    return ChatPipeline(settings, fake_llm, retriever, load_resources(DATA_DIR), factory)


@pytest.fixture
def client(pipeline):
    from app.main import app

    app.state.pipeline = pipeline
    with TestClient(app) as c:
        yield c
    app.state.pipeline = None
