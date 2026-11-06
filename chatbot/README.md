# MSU Hybrid Chatbot

AI service for the well-being companion app of Masjid Syamsul 'Ulum (MSU), Telkom University. It handles the chatbot conversation: risk triage, answers grounded in curated materials (RAG), activity suggestions, per-user memory, and summary drafts for psychologists.

The service runs separately from the mobile app and the main backend. The Flutter app in this repository is its interface (see [Using it from the Flutter app](#using-it-from-the-flutter-app)); the main backend can also call it over REST.

> The chatbot talks to students in Indonesian. The interface text, code and this README are in English.

## How it works

Every message goes through these steps:

1. **Save the user message first**, so nothing is lost if the LLM call fails.
2. **Layered risk triage**, running in parallel:
   - an Indonesian lexicon, including slang and masked words;
   - OpenAI Moderation (self-harm scores);
   - an LLM classifier (`gpt-5.4-nano`) that returns risk level, subject (self, someone else, general) and intent.

   The merge is fail-safe. If the classifier fails, the lexicon result still applies, and a `high` lexicon hit can never drop below `moderate`.
3. **Router**:
   - `crisis`: high risk about the user. The reply is a fixed, reviewable template plus verified help resources.
   - `report`: report requests go to the Reports screen. The AI does not interpret scores.
   - Generative routes: `rag`, `supportive_safety`, `concern_for_other`, `medical_boundary`.
4. **RAG**: the query is embedded (`text-embedding-3-small`) and matched with cosine similarity against the curated knowledge base.
5. **Generator** (`gpt-5.4-mini`, structured output) receives the materials, the activity catalog, the user's memory, the session summary and the recent history.
6. **Output guard** checks for diagnoses, medication names or doses, method details and foreign scripts. A violating reply is regenerated once; if it still fails, a safe fallback is used.
7. **Actions**: sources come only from retrieval hits, and activity ids are validated against the catalog. Psychologist and help buttons are added based on the risk level.
8. **Memory manager** (background, every 4 user messages) updates the user's memory and the session summary.

The architecture diagram is in [docs/arsitektur-ai.drawio](docs/arsitektur-ai.drawio). It has three pages: high level architecture, message flow, and AI models. Open it with draw.io or app.diagrams.net.

## Running locally

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env          # then set OPENAI_API_KEY
uvicorn app.main:app --port 8000
```

- API docs (Swagger): http://localhost:8000/docs

## Using it from the Flutter app

The chat screen of the Flutter app in this repository (`lib/features/chat/`) is the interface for this service. The app calls the `/chatbot/*` endpoints below, which speak the app's JSON contract (camelCase keys, `type: "crisis"` for crisis replies, `suggestions[].kind` for in-app exercises).

Run both on one machine:

```bash
# 1. chatbot service (from chatbot/), reachable from the emulator and the web build
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 2. Flutter app (from the repository root)
flutter run --dart-define=CHATBOT_BASE_URL=http://10.0.2.2:8000         # Android emulator
flutter run -d chrome --dart-define=CHATBOT_BASE_URL=http://localhost:8000  # web, needs CORS_ORIGINS
```

`CHATBOT_BASE_URL` defaults to `API_BASE_URL`, so once the main backend proxies `/chatbot/*` the extra define is not needed. Sign in with a demo account (*Masuk dengan akun demo*).

| Method | Path | Purpose |
|---|---|---|
| POST | `/chatbot/messages` | Send a message. Body: `text`, `conversationId` (optional), `displayName` (optional) |
| DELETE | `/chatbot/conversations/{conversationId}` | Delete a conversation ("Hapus riwayat chat") |
| POST | `/chatbot/conversations/{conversationId}/summary-draft` | Summary draft for the psychologist (never sent automatically) |
| GET / DELETE | `/chatbot/memory` | View or clear what the assistant remembers ("Memori Asisten AI") |
| DELETE | `/chatbot/memory/{memoryId}` | Delete one memory |

How the reply is mapped for the app:

- `route == "crisis"` becomes `type: "crisis"`, shown as the crisis card with help contacts.
- Activities that have their own screen in the app become `suggestions`: `napas-lambat` opens *Napas tenang* (`breathing`), `melepas-pikiran` opens *Lepaskan pikiran* (`release`). Other activities stay as `open_activity` actions with their steps, shown as a step-by-step sheet.
- `sources[]` keep the knowledge base id as `articleId` and add `sourceName` and `url`, so the chip opens the original WHO or Kemenkes page.

The user is identified from headers, never from the body:

- `Authorization: Bearer demo-session-<userId>`: the device token of the app's demo accounts. Accepted while `MOBILE_DEMO_TOKENS=true` (default). Set it to `false` in production.
- `Authorization: Bearer <Supabase access token>`: the real login session of the app. Verified against Supabase Auth (and the user's own active `PARTICIPANT` profile) when `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are set. See [docs/SUPABASE.md](docs/SUPABASE.md).
- `X-Service-Key` + `X-User-Id`: for the main backend, which verifies real accounts and forwards the request.

**Production note:** never ship `SERVICE_API_KEY` inside the app. Real accounts reach this service through the main backend, which checks the user's session and adds `X-Service-Key` and `X-User-Id`.

## Tests

```bash
pytest                      # unit tests, OpenAI is mocked
python -m eval.run_eval     # end-to-end evaluation against the real API
```

Evaluation results are saved to `eval/results/`.

## Backend endpoints

Service-to-service endpoints, used by the main backend:

| Method | Path | Purpose |
|---|---|---|
| POST | `/v1/chat` | Send a message. Body: `user_id`, `message`, `session_id` (optional), `display_name` (optional) |
| GET | `/v1/users/{user_id}/sessions` | The user's sessions |
| GET | `/v1/users/{user_id}/sessions/{session_id}/messages` | Message history |
| DELETE | `/v1/users/{user_id}/sessions/{session_id}` | Delete a session |
| POST | `/v1/users/{user_id}/sessions/{session_id}/summary-draft` | Summary draft for a psychologist (never sent automatically) |
| GET / DELETE | `/v1/users/{user_id}/memory` | View or clear the user's memory |
| DELETE | `/v1/users/{user_id}/memory/{memory_id}` | Delete one memory |
| GET | `/v1/activities`, `/v1/help-resources`, `/v1/knowledge-base` | Curated data for the app |

Action types in a chat response:

- `open_activity`
- `open_psychologist_chat`
- `prepare_summary`
- `call_phone`
- `open_url`
- `open_report`

When `SERVICE_API_KEY` is set, every request must include the `X-Service-Key` header. Sessions and memory are scoped to their `user_id`, so another user's session returns 404.

## Project layout

```
app/
  main.py            FastAPI app and service endpoints (/v1)
  mobile_api.py      endpoints for the Flutter app (/chatbot)
  pipeline.py        chatbot orchestration
  prompts.py         all prompts, kept together for review
  safety/            risk lexicon, triage, output guard
  rag/               knowledge base loader and retriever
  memory.py          per-user memory and session summaries
  db.py              database models (SQLAlchemy)
data/
  knowledge_base/    Markdown articles with source metadata (Indonesian)
  activities.yaml    non-clinical activity catalog
  help_resources.yaml  help resources, with a verified flag
  crisis_templates.yaml  fixed crisis templates
eval/                evaluation scenarios and script
tests/               unit tests (LLM mocked)
docs/                architecture diagram and progress report
```

## Adding knowledge base articles

Create a new `.md` file in `data/knowledge_base/` with this frontmatter:

```yaml
---
id: unique-id
title: Article title
topic: stres
tags: [keyword, keyword]
source_name: Source name
source_url: https://...
license: Summary and paraphrase with attribution
version: 1
status: published     # drafts are ignored by the chatbot
updated: 2026-10-22
---
```

Split the content with `##` headings. The embedding index rebuilds automatically on the next server start.
