from app.safety.triage import TriageOutput

DEMO = {"Authorization": "Bearer demo-session-usr_demo_rani"}


def send(client, text, conversation_id=None, headers=DEMO):
    r = client.post("/chatbot/messages", json={"text": text, "conversationId": conversation_id}, headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def test_reply_uses_app_contract(client, fake_llm):
    fake_llm.used_sources = ["mengelola-stres"]
    fake_llm.activities = ["napas-lambat", "grounding-dwm"]
    body = send(client, "aku stres banget sama tugas")
    assert body["role"] == "assistant" and body["type"] == "normal"
    assert body["conversationId"] and body["createdAt"]
    # napas-lambat punya layar sendiri di aplikasi, grounding dikirim lengkap dengan langkahnya
    assert body["suggestions"] == [{"kind": "breathing", "title": "Napas lambat 2 menit", "id": None}]
    activity = body["actions"][0]
    assert activity["type"] == "open_activity" and activity["payload"]["steps"]
    for source in body["sources"]:
        assert source["articleId"] and source["url"].startswith("https://")


def test_conversation_continues_and_survives_deleted_session(client):
    first = send(client, "halo")
    second = send(client, "lanjut", conversation_id=first["conversationId"])
    assert second["conversationId"] == first["conversationId"]

    r = client.delete(f"/chatbot/conversations/{first['conversationId']}", headers=DEMO)
    assert r.status_code == 204
    third = send(client, "halo lagi", conversation_id=first["conversationId"])
    assert third["conversationId"] != first["conversationId"]


def test_crisis_reply_has_crisis_type(client):
    body = send(client, "aku pengen bunuh diri malam ini")
    assert body["type"] == "crisis"
    assert "119" in body["text"]


def test_psychologist_actions_and_summary_draft(client, fake_llm):
    fake_llm.triage_override = TriageOutput(risk_level="none", subject="self",
                                            intent="psychologist_request", rationale="-")
    body = send(client, "aku mau ngobrol sama psikolog")
    types = [a["type"] for a in body["actions"]]
    assert "open_psychologist_chat" in types and "prepare_summary" in types

    r = client.post(f"/chatbot/conversations/{body['conversationId']}/summary-draft", headers=DEMO)
    assert r.status_code == 200
    draft = r.json()
    assert draft["status"] == "draft" and draft["summary"] and draft["topics"] == ["stres"]


def test_requires_known_session(client):
    r = client.post("/chatbot/messages", json={"text": "halo"})
    assert r.status_code == 401
    r = client.post("/chatbot/messages", json={"text": "halo"}, headers={"Authorization": "Bearer acak"})
    assert r.status_code == 401


def test_users_cannot_touch_each_other(client):
    body = send(client, "halo")
    other = {"Authorization": "Bearer demo-session-usr_demo_dimas"}
    r = client.post(f"/chatbot/conversations/{body['conversationId']}/summary-draft", headers=other)
    assert r.status_code == 404
    r = client.delete(f"/chatbot/conversations/{body['conversationId']}", headers=other)
    assert r.status_code == 404


def test_memory_list_and_clear(client):
    r = client.get("/chatbot/memory", headers=DEMO)
    assert r.status_code == 200 and r.json() == []
    assert client.delete("/chatbot/memory", headers=DEMO).status_code == 204
    assert client.delete("/chatbot/memory/tidak-ada", headers=DEMO).status_code == 404
