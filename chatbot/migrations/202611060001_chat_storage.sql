-- REVIEW REQUIRED. Not applied by app startup or tests.
-- Penyimpanan layanan chatbot (percakapan, memori, jejak keamanan) di Supabase Postgres.
-- Tabel hanya diakses server chatbot lewat koneksi Postgres; Data API (anon/authenticated)
-- tidak diberi akses sama sekali. Isi pesan bersifat pribadi: jangan dibuka lewat policy.
-- Prasyarat: migrasi backend/migrations/202611040001_checkins.sql sudah diterapkan
-- (schema chatbot dan ledger-nya ada). Jangan ubah file ini setelah diterapkan.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
SELECT pg_catalog.pg_advisory_xact_lock(20261106, 1);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'chatbot')
     OR pg_catalog.to_regclass('chatbot._backend_migrations') IS NULL THEN
    RAISE EXCEPTION 'schema chatbot belum ada; terapkan 202611040001_checkins lebih dulu';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM chatbot._backend_migrations WHERE version = '202611040001_checkins') THEN
    RAISE EXCEPTION 'ledger 202611040001_checkins tidak ditemukan';
  END IF;
  IF EXISTS (SELECT 1 FROM chatbot._backend_migrations WHERE version = '202611060001_chat_storage') THEN
    RAISE EXCEPTION 'migrasi ini sudah diterapkan';
  END IF;
  IF pg_catalog.to_regclass('chatbot.chat_sessions') IS NOT NULL
     OR pg_catalog.to_regclass('chatbot.messages') IS NOT NULL
     OR pg_catalog.to_regclass('chatbot.user_memories') IS NOT NULL
     OR pg_catalog.to_regclass('chatbot.safety_events') IS NOT NULL THEN
    RAISE EXCEPTION 'tabel chatbot sudah ada; rekonsiliasi, jangan menimpa';
  END IF;
END;
$$;

CREATE TABLE chatbot.chat_sessions (
  id varchar(32) PRIMARY KEY,
  user_id varchar(64) NOT NULL,  -- UUID auth.users dari token Supabase terverifikasi
  title varchar(200),
  summary text,
  max_risk_level varchar(16) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);
CREATE INDEX ix_chat_sessions_user_id ON chatbot.chat_sessions (user_id);

CREATE TABLE chatbot.messages (
  id varchar(32) PRIMARY KEY,
  session_id varchar(32) NOT NULL REFERENCES chatbot.chat_sessions (id),
  user_id varchar(64) NOT NULL,
  role varchar(16) NOT NULL,
  content text NOT NULL,
  risk_level varchar(16),
  intent varchar(32),
  route varchar(32),
  sources json,
  actions json,
  latency_ms integer,
  created_at timestamptz NOT NULL
);
CREATE INDEX ix_messages_session_id ON chatbot.messages (session_id);
CREATE INDEX ix_messages_user_id ON chatbot.messages (user_id);

CREATE TABLE chatbot.user_memories (
  id varchar(32) PRIMARY KEY,
  user_id varchar(64) NOT NULL,
  category varchar(32) NOT NULL,
  content text NOT NULL,
  source_session_id varchar(32),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);
CREATE INDEX ix_user_memories_user_id ON chatbot.user_memories (user_id);

-- Hanya sinyal risiko, bukan isi pesan.
CREATE TABLE chatbot.safety_events (
  id varchar(32) PRIMARY KEY,
  user_id varchar(64) NOT NULL,
  session_id varchar(32) NOT NULL,
  message_id varchar(32) NOT NULL,
  level varchar(16) NOT NULL,
  signals json NOT NULL,
  created_at timestamptz NOT NULL
);
CREATE INDEX ix_safety_events_session_id ON chatbot.safety_events (session_id);
CREATE INDEX ix_safety_events_user_id ON chatbot.safety_events (user_id);

-- RLS aktif tanpa policy + semua hak dicabut: Data API tidak bisa membaca/menulis tabel ini.
-- Server chatbot memakai role Postgres khusus (lihat chatbot/docs/SUPABASE.md).
REVOKE ALL ON chatbot.chat_sessions, chatbot.messages, chatbot.user_memories, chatbot.safety_events
  FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE chatbot.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot.user_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot.safety_events ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE chatbot.messages IS
  'Isi percakapan pribadi. Hanya server chatbot; jangan dibuka ke Data API.';

INSERT INTO chatbot._backend_migrations(version) VALUES ('202611060001_chat_storage');
COMMIT;
