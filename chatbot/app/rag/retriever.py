"""Vector store sederhana berbasis numpy dengan cache di disk.

Knowledge base berukuran puluhan dokumen, sehingga pencarian brute-force cosine
sudah cukup cepat. Bila korpus membesar, kelas ini dapat diganti pgvector
tanpa mengubah pipeline (antarmuka search tetap sama)."""

import json
import logging
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from ..llm import LLMClient
from .knowledge_base import Chunk, Document, chunk_document, corpus_hash, load_documents

log = logging.getLogger(__name__)


@dataclass
class Hit:
    chunk: Chunk
    document: Document
    score: float


class Retriever:
    def __init__(self, kb_dir: Path, cache_dir: Path):
        self.kb_dir = kb_dir
        self.cache_dir = cache_dir
        self.documents: dict[str, Document] = {}
        self.chunks: list[Chunk] = []
        self.matrix: np.ndarray | None = None

    async def build(self, llm: LLMClient) -> None:
        docs = load_documents(self.kb_dir)
        self.documents = {d.id: d for d in docs}
        self.chunks = [c for d in docs for c in chunk_document(d)]
        key = corpus_hash(self.chunks, llm.settings.embedding_model)

        cache_file = self.cache_dir / f"kb_index_{key}.npy"
        if cache_file.exists():
            self.matrix = np.load(cache_file)
            log.info("indeks KB dimuat dari cache (%d chunk)", len(self.chunks))
            return

        self.cache_dir.mkdir(parents=True, exist_ok=True)
        for old in self.cache_dir.glob("kb_index_*.npy"):
            old.unlink()
        self.matrix = await llm.embed([c.embed_text for c in self.chunks])
        np.save(cache_file, self.matrix)
        (self.cache_dir / "kb_index_meta.json").write_text(
            json.dumps({"hash": key, "chunks": [c.id for c in self.chunks]}, indent=1),
            encoding="utf-8",
        )
        log.info("indeks KB dibangun ulang (%d chunk)", len(self.chunks))

    def search(self, query_vec: np.ndarray, top_k: int, min_score: float) -> list[Hit]:
        if self.matrix is None or not self.chunks:
            return []
        scores = self.matrix @ query_vec
        order = np.argsort(-scores)[: top_k * 2]
        hits, seen_docs = [], {}
        for idx in order:
            score = float(scores[idx])
            if score < min_score:
                break
            chunk = self.chunks[idx]
            # maksimal dua chunk per dokumen agar konteks tidak didominasi satu materi
            if seen_docs.get(chunk.doc_id, 0) >= 2:
                continue
            seen_docs[chunk.doc_id] = seen_docs.get(chunk.doc_id, 0) + 1
            hits.append(Hit(chunk, self.documents[chunk.doc_id], score))
            if len(hits) == top_k:
                break
        return hits
