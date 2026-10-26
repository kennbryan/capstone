from app.safety.triage import TriageOutput


def send(client, text, session_id=None, user="u1"):
    r = client.post("/v1/chat", json={"user_id": user, "message": text, "session_id": session_id})
    assert r.status_code == 200, r.text
    return r.json()


def test_normal_message_uses_rag_and_activity(client, fake_llm):
    fake_llm.used_sources = ["mengelola-stres", "id-palsu"]
    body = send(client, "aku stres banget sama tugas")
    assert body["route"] == "rag"
    assert body["risk_level"] in ("none", "low")
    assert [a["type"] for a in body["actions"]] == ["open_activity"]
    # sumber hanya boleh dari hasil retrieval, id karangan model dibuang
    assert all(s["id"] != "id-palsu" for s in body["sources"])


def test_crisis_uses_fixed_template_without_generation(client, fake_llm):
    body = send(client, "aku pengen bunuh diri malam ini")
    assert body["route"] == "crisis"
    assert body["risk_level"] == "high"
    assert "119" in body["reply"]
    assert "ChatOutput" not in fake_llm.calls
    types = [a["type"] for a in body["actions"]]
    assert "call_phone" in types and "open_psychologist_chat" in types
    assert body["help_resources"]


def test_session_stays_in_safety_mode_after_crisis(client, fake_llm):
    first = send(client, "aku mau mati aja")
    second = send(client, "ya gitu deh", session_id=first["session_id"])
    assert second["route"] == "supportive_safety"


def test_concern_for_friend_is_not_crisis_template(client, fake_llm):
    fake_llm.triage_override = TriageOutput(risk_level="high", subject="other",
                                            intent="concern_for_other", rationale="-")
    body = send(client, "temenku bilang mau bunuh diri, aku harus gimana")
    assert body["route"] == "concern_for_other"
    assert body["help_resources"]


def test_report_request_routes_to_report_menu(client, fake_llm):
    fake_llm.triage_override = TriageOutput(risk_level="none", subject="self",
                                            intent="report_request", rationale="-")
    body = send(client, "skor asesmenku berapa ya?")
    assert body["route"] == "report"
    assert body["actions"][0]["type"] == "open_report"


def test_output_guard_fallback(client, fake_llm):
    fake_llm.chat_reply = "Kamu pasti mengalami depresi, minum sertraline 50 mg."
    body = send(client, "aku sedih terus")
    assert body["route"].endswith("guard_fallback")
    assert "sertraline" not in body["reply"]


def test_session_isolation_between_users(client):
    body = send(client, "halo", user="u1")
    r = client.post("/v1/chat", json={"user_id": "u2", "message": "hai", "session_id": body["session_id"]})
    assert r.status_code == 404
    r = client.get(f"/v1/users/u2/sessions/{body['session_id']}/messages")
    assert r.status_code == 404


def test_history_and_summary_draft(client):
    body = send(client, "aku capek kuliah")
    msgs = client.get(f"/v1/users/u1/sessions/{body['session_id']}/messages").json()
    assert [m["role"] for m in msgs] == ["user", "assistant"]
    draft = client.post(f"/v1/users/u1/sessions/{body['session_id']}/summary-draft").json()
    assert draft["status"] == "draft"


def test_memory_endpoints(client):
    assert client.get("/v1/users/u1/memory").json() == []
    assert client.delete("/v1/users/u1/memory").status_code == 204
