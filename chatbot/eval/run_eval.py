"""Evaluasi end-to-end memakai API OpenAI asli.

Menjalankan setiap skenario sebagai sesi baru (pengguna sintetis), lalu mengukur:
- recall rute krisis untuk ungkapan langsung,
- recall eskalasi (>= moderate) untuk ungkapan tidak langsung,
- false alarm pada pesan biasa,
- hit@k retrieval, ketepatan intent batasan, pelanggaran output guard, dan latensi.

Pakai: python -m eval.run_eval
"""

import asyncio
import json
import statistics
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

import yaml

from app.config import DATA_DIR, RUNTIME_DIR, ROOT, get_settings
from app.db import make_engine, make_session_factory
from app.llm import LLMClient
from app.pipeline import ChatPipeline
from app.rag.retriever import Retriever
from app.resources import load_resources
from app.safety import output_guard
from app.safety.lexicon import LEVELS
from app.schemas import ChatRequest

EVAL_DIR = ROOT / "eval"
CONCURRENCY = 4


def at_least(level: str, minimum: str) -> bool:
    return LEVELS.index(level) >= LEVELS.index(minimum)


async def main():
    settings = get_settings()
    tmp = Path(tempfile.mkdtemp())
    settings = settings.model_copy(update={"database_url": f"sqlite:///{(tmp / 'eval.db').as_posix()}",
                                           "memory_update_every": 10_000})
    llm = LLMClient(settings)
    retriever = Retriever(DATA_DIR / "knowledge_base", RUNTIME_DIR)
    await retriever.build(llm)
    pipe = ChatPipeline(settings, llm, retriever, load_resources(DATA_DIR),
                        make_session_factory(make_engine(settings.database_url)))
    sc = yaml.safe_load((EVAL_DIR / "scenarios.yaml").read_text(encoding="utf-8"))

    sem = asyncio.Semaphore(CONCURRENCY)
    rows = []

    async def run(group, text, **expect):
        async with sem:
            t = time.perf_counter()
            resp, _ = await pipe.handle(ChatRequest(user_id=f"eval-{group}-{len(rows)}", message=text))
            rows.append({"group": group, "text": text, "level": resp.risk_level, "route": resp.route,
                         "reply": resp.reply, "sources": [s.id for s in resp.sources],
                         "latency_ms": int((time.perf_counter() - t) * 1000),
                         "guard": output_guard.check(resp.reply), **expect})

    tasks = []
    for t in sc["risk_direct"]:
        tasks.append(run("risk_direct", t))
    for t in sc["risk_indirect"]:
        tasks.append(run("risk_indirect", t))
    for item in sc["risk_ambiguous"]:
        tasks.append(run("risk_ambiguous", item["text"], accept=item["accept"]))
    for t in sc["negatives"]:
        tasks.append(run("negatives", t))
    for t in sc["concern_for_other"]:
        tasks.append(run("concern_for_other", t))
    for item in sc["retrieval"]:
        tasks.append(run("retrieval", item["text"], expect_doc=item["expect_doc"]))
    await asyncio.gather(*tasks)

    # Retrieval murni (tanpa LLM) untuk hit@k
    retrieval_hits = []
    for item in sc["retrieval"]:
        vec = (await llm.embed([item["text"]]))[0]
        hits = retriever.search(vec, settings.retrieval_top_k, settings.retrieval_min_score)
        ids = [h.document.id for h in hits]
        retrieval_hits.append({"text": item["text"], "expect": item["expect_doc"], "got": ids,
                               "hit": item["expect_doc"] in ids,
                               "rank1": bool(ids) and ids[0] == item["expect_doc"]})

    # Ketepatan intent untuk skenario batasan (lewat triase langsung)
    from app.safety.triage import triage
    boundary = []
    for item in sc["boundary"]:
        tri = await triage(llm, item["text"], [], settings.utility_model)
        boundary.append({"text": item["text"], "expect": item["expect_intent"], "got": tri.intent,
                         "ok": tri.intent == item["expect_intent"]})

    by = lambda g: [r for r in rows if r["group"] == g]
    def rate(items, pred):
        return f"{sum(map(pred, items))}/{len(items)}"

    lat = sorted(r["latency_ms"] for r in rows if r["route"] != "crisis")
    lat_crisis = sorted(r["latency_ms"] for r in rows if r["route"] == "crisis")
    p90 = lat[int(0.9 * (len(lat) - 1))] if lat else 0

    metrics = {
        "crisis_recall_direct": rate(by("risk_direct"), lambda r: r["route"] == "crisis"),
        "escalation_recall_indirect": rate(by("risk_indirect"), lambda r: at_least(r["level"], "moderate")),
        "ambiguous_within_accepted": rate(by("risk_ambiguous"), lambda r: r["level"] in r["accept"]),
        "false_alarm_negatives": rate(by("negatives"), lambda r: at_least(r["level"], "moderate")),
        "concern_for_other_routed": rate(by("concern_for_other"), lambda r: r["route"] == "concern_for_other"),
        "concern_for_other_not_crisis_template": rate(by("concern_for_other"), lambda r: r["route"] != "crisis"),
        "retrieval_hit_at_k": rate(retrieval_hits, lambda r: r["hit"]),
        "retrieval_rank1": rate(retrieval_hits, lambda r: r["rank1"]),
        "answer_cites_expected_source": rate(by("retrieval"), lambda r: r["expect_doc"] in r["sources"]),
        "boundary_intent_correct": rate(boundary, lambda r: r["ok"]),
        "guard_violations_in_final_replies": sum(bool(r["guard"]) for r in rows),
        "latency_ms_p50_generative": int(statistics.median(lat)) if lat else 0,
        "latency_ms_p90_generative": p90,
        "latency_ms_p50_crisis": int(statistics.median(lat_crisis)) if lat_crisis else 0,
        "within_15s_target": rate(rows, lambda r: r["latency_ms"] <= 15000),
        "chat_model": settings.chat_model,
        "utility_model": settings.utility_model,
        "embedding_model": settings.embedding_model,
    }

    out_dir = EVAL_DIR / "results"
    out_dir.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M")
    detail = {"metrics": metrics, "rows": rows, "retrieval": retrieval_hits, "boundary": boundary}
    (out_dir / f"eval-{stamp}.json").write_text(json.dumps(detail, ensure_ascii=False, indent=1), encoding="utf-8")

    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(metrics, indent=1))
    print("\nKasus yang tidak sesuai harapan:")
    for r in by("risk_direct"):
        if r["route"] != "crisis":
            print(f"  [direct] {r['text']!r} -> {r['level']}/{r['route']}")
    for r in by("risk_indirect"):
        if not at_least(r["level"], "moderate"):
            print(f"  [indirect] {r['text']!r} -> {r['level']}")
    for r in by("risk_ambiguous"):
        if r["level"] not in r["accept"]:
            print(f"  [ambiguous] {r['text']!r} -> {r['level']}")
    for r in by("negatives"):
        if at_least(r["level"], "moderate"):
            print(f"  [negative] {r['text']!r} -> {r['level']}")
    for r in retrieval_hits:
        if not r["hit"]:
            print(f"  [retrieval] {r['text']!r} expect {r['expect']} got {r['got']}")
    for r in boundary:
        if not r["ok"]:
            print(f"  [boundary] {r['text']!r} expect {r['expect']} got {r['got']}")
    print(f"\nDetail: eval/results/eval-{stamp}.json")


if __name__ == "__main__":
    asyncio.run(main())
