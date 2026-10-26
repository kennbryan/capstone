from app.config import DATA_DIR
from app.rag.knowledge_base import chunk_document, load_documents
from app.resources import load_resources


def test_knowledge_base_valid():
    docs = load_documents(DATA_DIR / "knowledge_base", include_drafts=True)
    assert len(docs) >= 10
    for doc in docs:
        assert doc.source_url, doc.id
        assert chunk_document(doc), doc.id


def test_resources_valid():
    res = load_resources(DATA_DIR)
    assert res.crisis_help, "harus ada info bantuan terverifikasi untuk krisis"
    for key in ("self_harm_high", "harm_others_high", "llm_unavailable", "guard_fallback", "report_request"):
        assert res.crisis_templates[key].strip()
    for act in res.activities.values():
        assert act["steps"] and act["source_url"], act["id"]


def test_crisis_template_mentions_verified_hotline():
    res = load_resources(DATA_DIR)
    text = res.crisis_templates["self_harm_high"]
    assert "119" in text and "112" in text
