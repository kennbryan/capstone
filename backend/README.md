# MSU Well-being companion backend

Backend utama aplikasi pendamping. Menyediakan **GET /me**, **GET /checkins** dan
**POST /checkins**. Migrasi/exposure dan pengujian dua akun sudah lulus di staging;
penerapan pada database website belum dilakukan dalam pekerjaan ini. Lihat
[panduan penerapan](docs/CHECKINS-ROLLOUT.md) dan
[handover Flutter](docs/FLUTTER-INTEGRATION-HANDOVER.md).
Login dilakukan Flutter melalui Supabase Auth; backend ini tidak menerima
password atau membuat sesi login baru. Layanan AI tetap berada di `chatbot/`.

## Menjalankan di Windows (PowerShell)

Python 3.12 direkomendasikan. Buka terminal pada folder `backend`:

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
python -m venv .venv
& '.\.venv\Scripts\python.exe' -m pip install -r requirements.lock
& '.\.venv\Scripts\python.exe' -m uvicorn app.main:app --host 127.0.0.1 --port 8001 --no-access-log
```

Jika `.venv` sudah tersedia, lewati perintah pembuatannya. Tidak perlu activate
atau mengubah PowerShell execution policy. Environment harus tetap berada pada
lokasi ini; buat ulang jika project dipindahkan. Port 8001 menghindari benturan
dengan chatbot yang biasanya memakai port 8000.

Konfigurasi dibaca dari `backend/.env`, terlepas dari working directory.
Environment variable proses memiliki prioritas atas `.env`:

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

URL harus HTTPS tanpa `/rest/v1/`, query, fragment, atau credential. Key wajib
berjenis `sb_publishable_...`; jangan gunakan secret/service-role key.
`.env` dan `.venv` diabaikan Git. Isi `.env` tidak boleh disalin ke dokumentasi,
log, screenshot, atau laporan pengujian. `requirements.lock` merekam versi
dependency yang diuji; `requirements.txt` menyatakan rentang dependency.

Swagger lokal: <http://127.0.0.1:8001/docs>. Gunakan tombol **Authorize** dengan
access token dari sesi Supabase akun uji yang sudah diizinkan. Publishable key
bukan access token pengguna. Jangan memasukkan token ke URL atau mengirimkannya
ke chat. Menjalankan request dengan token nyata memanggil Auth/Data API nyata;
persetujuan test lokal sintetis tidak otomatis menjadi persetujuan pengujian ini.

## Kontrak GET /me

Request:

```http
GET /me
Authorization: Bearer <access-token-pengguna>
```

Response 200 (langsung object, tanpa envelope `data`, sesuai `UserDto` Flutter):

```json
{
  "id": "11111111-1111-4111-8111-111111111111",
  "displayName": "Pengguna Sintetis",
  "email": "synthetic@example.invalid"
}
```

`displayName` dipetakan dari `public.users.full_name`. Nama panggilan lokal
Flutter belum disinkronkan. Endpoint mengenali role website PARTICIPANT,
PSYCHOLOGIST, dan SUPERADMIN; ini hanya pembacaan profil sendiri, bukan pemberian
hak untuk fitur/rapor pengguna lain. Endpoint bisnis berikutnya harus memeriksa
role dan kepemilikannya sendiri.

Error aman berbentuk `{ "error": "KODE", "message": "Pesan pengguna" }`:

| Status | Kode | Arti |
| --- | --- | --- |
| 401 | UNAUTHORIZED | Bearer tidak ada/malformed, Auth menolak token, user anonim atau email belum terkonfirmasi |
| 403 | FORBIDDEN | Profil tidak terlihat/tidak ada/nonaktif, user banned, atau role tidak dikenal |
| 503 | SERVICE_UNAVAILABLE | Timeout, gangguan Auth/Data API, masalah key/grants/schema, atau response upstream tidak sesuai kontrak |

Semua response memakai `Cache-Control: private, no-store, max-age=0`. Error 401
membawa `WWW-Authenticate: Bearer`; 503 membawa `Retry-After: 5`. Error key atau
permission yang tidak dikenali tidak boleh menandakan password salah/logout.

## Alur dan batas akses

1. Validasi header Bearer; token/role/userId dari body atau query bukan identitas.
2. `GET /auth/v1/user` ke project terkonfigurasi, menggunakan `apikey` publishable
   dan `Authorization` token pengguna. Identitas tidak diambil dari decode JWT
   lokal yang belum diverifikasi atau dari `user_metadata`.
3. Pastikan UUID valid, bukan user anonim, dan email terkonfirmasi.
4. `GET /rest/v1/users`, pilih **hanya** `id,full_name,email,role,is_active`, filter
   `id=eq.<UUID terverifikasi>`. Token pengguna diteruskan per request sehingga RLS
   berlaku. Token tidak disimpan sebagai default header client bersama.
5. Periksa ID response, status aktif dan role; kembalikan tiga field Flutter.

RLS `users_read_own_active_profile` dapat menyembunyikan baris nonaktif sebagai
hasil kosong; backend sengaja tidak membedakan profil hilang dan nonaktif.
Tidak ada `SELECT *` atau akses tabel assessment. Endpoint check-in memakai
schema terpisah dan JWT pengguna; migrasi tidak pernah dijalankan saat startup.
HTTP client memvalidasi TLS, tidak mengikuti redirect, tidak mengambil proxy dari
environment, memakai timeout per operasi jaringan 5 detik dan budget total 12
detik. Kegagalan upstream tidak meneruskan body atau teks exception ke pengguna.

Supabase harus mengaktifkan Data API, mengekspos schema `public`, memberi schema
USAGE dan SELECT pada lima kolom untuk role `authenticated`, serta memiliki RLS
profil sendiri. Screenshot policy dan grants bukan pengganti pengujian dengan
token pengguna. Validitas koneksi nyata tidak dibuktikan oleh test sintetis.
Pada pengujian manual yang dilaporkan pengguna, login kedua akun sintetis dan
GET /me berhasil, profil sendiri terbaca dan profil akun lain tidak terlihat
melalui Data API. Pengujian staging berikutnya juga membuktikan simpan/replace,
isolasi baca/tulis check-in dan baca ulang dari proses baru. /me dan riwayat dua
akun lulus melalui HTTP port 8002; laporan `docs/evidence/staging-http-verification.json`.
POST check-in HTTP dan integrasi UI Flutter masih perlu diuji.

## Kontrak check-in dan database

Backup sebelum penerapan: [BACKUP-BEFORE-CHECKINS.md](docs/BACKUP-BEFORE-CHECKINS.md).
Tools portabel berada pada .backup-tools dan arsip terenkripsi pada private-backups;
keduanya diabaikan Git. Menyiapkan tools tidak berarti backup nyata sudah dibuat.

- GET `/checkins?from=YYYY-MM-DD&to=YYYY-MM-DD`: array langsung, rentang inklusif
  maksimal 366 hari, hanya milik pengguna aktif dengan role PARTICIPANT.
- POST `/checkins`: `{date,mood,note?}`, mood integer 1–5, note maksimal 200
  karakter setelah trim. Response 200 langsung `{id,date,mood,note?}`.
- Satu baris per UUID pengguna/tanggal. POST tanggal sama mengganti mood/catatan;
  note tidak dikirim/null/kosong menghapus catatan sebelumnya. ID dipertahankan.
- Identitas dari Auth terverifikasi; user_id/id/role dari body/query ditolak.
  Body JSON maksimal 4096 byte, duplicate keys ditolak; error tidak mengulang
  catatan atau input privat. Timeout POST tidak diulang otomatis.
- Migration review: `migrations/202611040001_checkins.sql`. Menambah schema
  chatbot dan ledger terpisah, tanpa mengubah objek/ledger website. Gagal bila
  schema sudah ada: harus rekonsiliasi, bukan drop schema atau menimpa objek.
- `sql/checkins_preflight.sql` dan `sql/checkins_verify.sql` hanya membaca
  metadata. Penerapan migrasi/exposure memerlukan persetujuan pemilik database.
- Grants + RLS memeriksa pemilik dan profil aktif PARTICIPANT, termasuk akses
  Data API langsung. Runtime tidak menggunakan Secret key atau koneksi postgres.

Detail kontrak, ownership, risiko akses langsung, langkah review, rollback,
pengujian live dan batas bukti: [CHECKINS-ROLLOUT.md](docs/CHECKINS-ROLLOUT.md).

## Pengujian lokal sintetis

Dari folder `backend`:

```powershell
& '.\.venv\Scripts\python.exe' -m pytest
& '.\.venv\Scripts\python.exe' -m pip check
```

Test memakai HTTPX MockTransport, project `.invalid`, UUID/akun sintetis, serta
Settings yang tidak membaca `.env`. Tidak ada request ke Supabase/OpenAI nyata.
Cakupan: bentuk response Flutter, verifikasi sebelum query, token/metadata
palsu, kepemilikan dua user konkuren, status profil/role, kegagalan key/permission,
timeout, JSON rusak, redaksi error, no-store, dan validasi konfigurasi.

Verifikasi lokal 4 November 2026 pada Python 3.12.14 dan `requirements.lock`:
196 test lulus dengan `python -B -m pytest -W error`, termasuk seluruh 75 test
/me sebelumnya, kontrak check-in dan workflow alat pengujian live menggunakan
transport palsu. `pip check` tidak menemukan dependency rusak. Tidak ada
PostgreSQL/PostgREST lokal atau database hosted yang diuji oleh suite ini.
Smoke test Uvicorn tahap /me sebelumnya berhasil memuat konfigurasi lokal, membuka
`/docs` (200), dan menolak `/me` tanpa token (401, no-store), kemudian server
dihentikan. Pemeriksaan ini tidak memanggil Supabase atau membaca data akun nyata.

Smoke test Uvicorn versi check-in juga lulus pada port sementara dengan Settings
sintetis yang tidak membaca .env: /docs dan OpenAPI 200; /me serta GET/POST
/checkins tanpa token 401; body oversized 413 dengan no-store. Server sementara
dihentikan sesudah pemeriksaan; server pengguna pada port 8001 tidak disentuh.

Sandbox Windows tertentu memblokir socket internal event loop Python, bahkan
untuk MockTransport. Jika pytest tertahan sebelum test pertama, jalankan terminal
lokal biasa; jangan mengganti target menjadi database nyata untuk mengatasinya.

## Status integrasi dan langkah berikutnya

- Flutter saat ini masih mempunyai source login `/auth/login`; Kenneth perlu
  menghubungkan login/refresh/logout langsung ke Supabase sesuai kesepakatan.
- Arahkan `API_BASE_URL` Flutter ke backend ini setelah integrasi tersebut siap.
  Check-in tersedia di kode tetapi belum dapat dipakai sebelum migrasi dan
  exposure disetujui/diterapkan. Android menolak HTTP berdasarkan network
  config saat ini; penggunaan emulator memerlukan HTTPS development atau perubahan
  konfigurasi debug yang ditinjau terpisah. Backend sekarang bind loopback saja.
- Belum ada CORS browser, rate limiter, deployment, consent API, adapter
  rapor, atau gateway chatbot pada service ini. Perubahan tersebut memerlukan
  tahap dan konfirmasi berikutnya. Untuk deployment publik, tentukan HTTPS,
  pembatasan request dan logging yang tidak merekam header/body pengguna.
- Setelah migrasi dan schema exposure lolos review, tool pengujian dua akun:
  `python -B -m tools.verify_checkins --date 2000-01-01`. Ia menulis check-in
  sintetis hanya bila tanggal itu kosong pada kedua akun. Setelah restart
  backend, ulangi dengan `--verify-only`; mode tersebut hanya membaca check-in
  tetapi login tetap membuat sesi Auth. Jangan jalankan sebelum target disetujui.

Referensi implementasi:
- <https://supabase.com/docs/guides/auth/jwts>
- <https://supabase.com/docs/guides/getting-started/api-keys>
- <https://supabase.com/docs/guides/api/securing-your-api>
