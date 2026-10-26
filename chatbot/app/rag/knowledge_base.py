"""Memuat materi knowledge base (Markdown + frontmatter YAML) dan memecahnya per bagian."""

import hashlib
from dataclasses import dataclass
from pathlib import Path

import yaml

REQUIRED_FIELDS = {"id", "title", "topic", "source_name", "source_url", "status", "version"}


@dataclass
class Document:
    id: str
    title: str
    topic: str
    tags: list[str]
    source_name: str
    source_url: str
    license: str
    version: str
    status: str  # published | draft
    updated: str
    body: str


@dataclass
class Chunk:
    id: str
    doc_id: str
    title: str
    heading: str
    text: str

    @property
    def embed_text(self) -> str:
        return f"{self.title}. {self.heading}\n{self.text}"


def parse_document(path: Path) -> Document:
    raw = path.read_text(encoding="utf-8")
    if not raw.startswith("---"):
        raise ValueError(f"{path.name}: frontmatter tidak ditemukan")
    _, front, body = raw.split("---", 2)
    meta = yaml.safe_load(front)
    missing = REQUIRED_FIELDS - meta.keys()
    if missing:
        raise ValueError(f"{path.name}: field wajib hilang {sorted(missing)}")
    return Document(
        id=meta["id"],
        title=meta["title"],
        topic=meta["topic"],
        tags=meta.get("tags", []),
        source_name=meta["source_name"],
        source_url=meta["source_url"],
        license=meta.get("license", ""),
        version=str(meta["version"]),
        status=meta["status"],
        updated=str(meta.get("updated", "")),
        body=body.strip(),
    )


def load_documents(directory: Path, include_drafts: bool = False) -> list[Document]:
    docs = [parse_document(p) for p in sorted(directory.glob("*.md"))]
    ids = [d.id for d in docs]
    if len(ids) != len(set(ids)):
        raise ValueError("id dokumen knowledge base duplikat")
    return [d for d in docs if include_drafts or d.status == "published"]


def chunk_document(doc: Document) -> list[Chunk]:
    """Satu chunk per heading level 2. Materi well-being pendek, jadi ini cukup."""
    chunks: list[Chunk] = []
    heading, lines = "Ringkasan", []

    def flush():
        text = "\n".join(lines).strip()
        if text:
            chunks.append(Chunk(f"{doc.id}#{len(chunks)}", doc.id, doc.title, heading, text))

    for line in doc.body.splitlines():
        if line.startswith("## "):
            flush()
            heading, lines = line[3:].strip(), []
        elif not line.startswith("# "):
            lines.append(line)
    flush()
    return chunks


def corpus_hash(chunks: list[Chunk], embedding_model: str) -> str:
    h = hashlib.sha256(embedding_model.encode())
    for c in chunks:
        h.update(c.id.encode())
        h.update(c.embed_text.encode())
    return h.hexdigest()[:16]
