# Menghubungkan chatbot ke Supabase

Dua bagian terpisah. Keduanya opsional dan tidak mengubah mode lokal (SQLite + token demo).

## 1. Login: verifikasi token Supabase

Flutter mengirim `Authorization: Bearer <access token Supabase>` ke `CHATBOT_BASE_URL`. Chatbot
memverifikasinya seperti backend utama (`backend/app/auth.py`): `GET /auth/v1/user`, lalu membaca
profil sendiri lewat Data API dengan token yang sama (RLS berlaku). Syarat: email terkonfirmasi,
bukan anonim, profil `is_active` dan role `PARTICIPANT`. Hasil verifikasi di-cache 60 detik per token.

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
MOBILE_DEMO_TOKENS=false   # staging/produksi
```

Hanya publishable key. Kode status: 401 token tidak valid, 403 akun tidak diizinkan,
503 Supabase tidak dapat dihubungi.

## 2. Penyimpanan: Postgres Supabase

1. Terapkan `backend/migrations/202611040001_checkins.sql` (membuat schema `chatbot`), lalu
   `chatbot/migrations/202611060001_chat_storage.sql`. Keduanya perlu review dan persetujuan
   pemilik database; aplikasi tidak pernah menjalankan migrasi saat startup.
2. Buat role Postgres khusus untuk server chatbot (kata sandi dibuat sendiri, jangan di git):

   ```sql
   CREATE ROLE chatbot_app LOGIN PASSWORD '<kata-sandi-kuat>';
   GRANT USAGE ON SCHEMA chatbot TO chatbot_app;
   GRANT SELECT, INSERT, UPDATE, DELETE ON chatbot.chat_sessions, chatbot.messages,
     chatbot.user_memories, chatbot.safety_events TO chatbot_app;
   CREATE POLICY chatbot_app_all ON chatbot.chat_sessions FOR ALL TO chatbot_app USING (true) WITH CHECK (true);
   CREATE POLICY chatbot_app_all ON chatbot.messages FOR ALL TO chatbot_app USING (true) WITH CHECK (true);
   CREATE POLICY chatbot_app_all ON chatbot.user_memories FOR ALL TO chatbot_app USING (true) WITH CHECK (true);
   CREATE POLICY chatbot_app_all ON chatbot.safety_events FOR ALL TO chatbot_app USING (true) WITH CHECK (true);
   ```

   Tabel memakai RLS tanpa policy untuk `anon`/`authenticated`, jadi Data API tidak bisa
   membacanya. Pemisahan antarpengguna dijaga kode (`user_id` dari token terverifikasi).
3. Isi `.env` (jangan di-commit). String koneksi dari Supabase Dashboard > Connect, mode Session
   pooler (port 5432) atau Transaction pooler (port 6543; sudah didukung):

   ```dotenv
   DATABASE_URL=postgresql+psycopg://chatbot_app.<project-ref>:<kata-sandi>@<host-pooler>:5432/postgres
   ```

4. Jalankan seperti biasa: `uvicorn app.main:app --host 0.0.0.0 --port 8000`.
   Aktifkan `SERVICE_API_KEY` agar rute `/v1/*` tidak terbuka.

## Server staging (Docker)

`chatbot/Dockerfile` membangun image siap pakai (Python 3.13, pengguna non-root, healthcheck di
`/health`, token demo mati secara default). Image sudah diuji lokal: `/health` 200, token demo dan
token palsu ditolak 401. Platform apa pun yang menjalankan Docker bisa dipakai (Render, Railway,
Fly.io, Cloud Run, VPS). Pilih satu yang punya HTTPS otomatis dan konektivitas keluar ke port
5432 (database) dan 443 (OpenAI, Supabase).

```bash
cd chatbot
docker build -t chatbot-msu .
docker run -p 8000:8000 --env-file .env chatbot-msu   # uji lokal; .env tidak ikut ke image
```

Isi environment variable berikut di dasbor platform (rahasia diisi pemilik akun, jangan di git):

| Variabel | Nilai |
|---|---|
| `OPENAI_API_KEY` | kunci OpenAI (rahasia) |
| `DATABASE_URL` | `postgresql+psycopg://chatbot_app.<ref>:<sandi>@<host-pooler>:5432/postgres` (rahasia) |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_...` |
| `SERVICE_API_KEY` | string acak panjang; melindungi rute `/v1/*` (rahasia) |
| `MOBILE_DEMO_TOKENS` | `false` |
| `CORS_ORIGINS` | hanya jika Flutter web dipakai, mis. `https://app-staging.example.com` |

Setelah live: `GET https://<host>/health` harus `status: ok`, lalu jalankan Flutter dengan
`--dart-define=CHATBOT_BASE_URL=https://<host>`. Satu instance cukup: indeks KB dibangun saat
startup (butuh akses OpenAI) dan percakapan disimpan di Postgres, bukan di disk container.
Isi pesan pengguna dikirim ke OpenAI; pastikan persetujuan (consent) pengguna ada sebelum dipakai
pengguna nyata.
