# Check-in: rancangan, review dan penerapan

Status terkini: implementasi lokal tersedia. Pengguna telah menjalankan migrasi
dan mengirim metadata verifikasinya pada staging `orxbprfixonwdwgjqmpv`, serta
mengonfirmasi exposure schema `chatbot`. Login/RLS profil, uji simpan check-in,
isolasi baca/tulis dua akun dan baca ulang dari proses baru sudah lulus di staging
(laporan `staging-checkins-verification.json` dan `staging-checkins-readback.json`).
Pengujian memakai rute FastAPI dalam proses dengan Supabase staging nyata;
akses HTTP /me dan baca riwayat juga lulus menurut `staging-http-verification.json`.
POST check-in HTTP, Flutter dan deployment belum dibuktikan. Database website belum
dimigrasikan dalam rangkaian pekerjaan ini. Usulan penerapan pada database website
tetap memerlukan persetujuan tersendiri dari tim/pemiliknya.

Untuk langkah staging gunakan `tools.verify_staging_checkins`, bukan tool default
yang membaca .env. Perintah dan batas buktinya ada di `STAGING-RESTORE.md`.
Bagian verifikasi lokal di akhir dokumen ini adalah catatan historis saat persiapan;
bukti native PostgreSQL dan status staging yang lebih baru ada di dokumen tersebut.

## Batas perubahan

- Tambahan schema `chatbot`, tabel `checkins`, ledger `_backend_migrations`,
  fungsi trigger dan tiga policy check-in. Tidak mengubah objek website/Auth.
- Identitas tetap `auth.users.id`. Tidak menggandakan profil atau mengambil
  identitas/role dari body, query atau user metadata.
- FK check-in ke Auth memakai `ON DELETE RESTRICT`. Penghapusan akun/check-in
  dan kebijakan retensi memerlukan rancangan terpisah; tidak ada DELETE API.
- Tidak mengirim catatan ke AI, tidak memberi chatbot akses assessment/rapor.
- Backend hanya memakai publishable key + JWT pengguna, bukan key istimewa.
  Pendekatan Data API ini tidak memakai koneksi SQL/runtime DB role terpisah.
  Jika kemudian beralih ke SQL langsung, buat role runtime khusus terlebih dahulu.
- `authenticated` adalah role bersama. Pengguna berhak dapat mengakses check-in
  sendiri melalui Data API secara langsung. Ini isolasi **per pengguna**, bukan
  larangan akses berdasarkan aplikasi asal. Jika hanya FastAPI yang boleh
  mengakses database, hentikan penerapan rancangan ini dan tinjau opsi schema
  privat + kredensial runtime terbatas; jangan mengganti JWT dengan Secret key.

## Kontrak untuk Kenneth

Sumber kontrak: `lib/features/checkin/data/sources/checkin_sources.dart` dan
`lib/features/checkin/data/models/check_in_dto.dart`.

`GET /checkins?from=2026-11-01&to=2026-11-07`, Bearer JWT pengguna:

```json
[{"id":"33333333-3333-4333-8333-333333333333","date":"2026-11-04","mood":4,"note":"catatan sintetis"}]
```

Rentang inklusif 1–366 hari; kedua parameter wajib, tanpa parameter tambahan
atau duplikat; tanggal persis `YYYY-MM-DD`; urutan menaik. Hasil kosong `[]`.

`POST /checkins`, Content-Type application/json + Bearer JWT pengguna:

```json
{"date":"2026-11-04","mood":4,"note":"catatan sintetis"}
```

Selalu 200 saat berhasil, satu object dengan bentuk yang sama. ID string UUID
cocok dengan DTO Flutter; contoh ID `chk_...` di komentar Flutter bukan kewajiban
format. Body tidak boleh memiliki user_id/id/role/timestamp/field lain atau
query. Mood wajib integer 1–5, bukan string/boolean/pecahan.

Catatan dipangkas whitespace tepinya, maksimal 200 Unicode code points setelah
pemangkasan. NUL dan Unicode surrogate tidak valid ditolak. Note tidak dikirim,
null atau kosong berarti **menghapus catatan sebelumnya** pada penggantian;
response tanpa catatan menghilangkan field note. Ini operasi penggantian, bukan
PATCH. Batas body 4096 byte, timeout pengiriman body 10 detik; JSON duplikat ditolak.
Flutter menghitung panjang string/tampilan dengan aturan Unicode yang mungkin
berbeda; backend tetap menegakkan batas ini dan perlu diuji dengan emoji di UI.

`date` adalah tanggal kalender yang dikirim aplikasi, tidak dikonversi ke UTC.
created_at/updated_at disimpan sebagai timestamptz. Tidak membatasi tanggal ke
hari ini atau menolak backfill/future date: zona waktu dan kebijakan tersebut
belum disepakati. Jangan menambahkan pembatasan diam-diam di salah satu layer.

Satu baris unik `(user_id,date)`; POST memakai atomic PostgREST upsert
`on_conflict=user_id,date`, `resolution=merge-duplicates,return=representation`.
ID dan created_at dipertahankan; updated_at ditentukan database. Concurrent
saves pada tanggal sama menggunakan hasil penulisan terakhir, bukan revision
control. Tidak ada retry otomatis. Setelah timeout POST, baca kembali tanggal
tersebut sebelum memutuskan mengulang: transaksi mungkin telah commit.

Error `{error,message}` tanpa mengulang body privat:

| HTTP | Kode | Makna |
| --- | --- | --- |
| 401 | UNAUTHORIZED | Token kosong/tidak sah/kedaluwarsa, akun belum terkonfirmasi/anonim |
| 403 | FORBIDDEN | Profil tidak aktif/tidak terlihat, role bukan PARTICIPANT, user banned |
| 408 | REQUEST_TIMEOUT | Body tidak selesai dikirim dalam batas waktu |
| 413 | PAYLOAD_TOO_LARGE | Body lebih dari 4096 byte |
| 415 | UNSUPPORTED_MEDIA_TYPE | Body bukan application/json |
| 422 | VALIDATION_ERROR | Tanggal/range/mood/note/JSON/field permintaan tidak valid |
| 503 | CHECKINS_UNAVAILABLE | Gangguan persistence/response, schema/grants/RLS belum siap, timeout |
| 503 | SERVICE_UNAVAILABLE | Gangguan verifikasi Auth/profil yang dipakai bersama /me |

Semua response no-store; 401 WWW-Authenticate, 503 Retry-After. Jika RLS menolak
saat profil berubah sesudah pemeriksaan awal, error upstream tidak dipakai untuk
menganggap password salah: endpoint gagal tertutup dengan 503. Retry-After bukan
izin bagi aplikasi untuk otomatis mengulang POST.

## Ownership dan urutan persetujuan

1. Ferdiansyah menyiapkan SQL, API, tests dan bukti; Kenneth meninjau kontrak UI.
2. Pemilik database memastikan target development/staging yang disetujui,
   collision schema, grants, memberships, backup yang dapat dipulihkan dan window.
3. Satu koordinator menjalankan migrasi yang disetujui. Jangan menjalankan Prisma
   migrate/db push/reset dari repo pendamping terhadap ledger website.
4. Catat persetujuan, target (tanpa credential), checksum file, waktu dan bukti.
   Jangan mengedit file migrasi setelah diterapkan; perubahan lewat versi baru.

## Langkah operator (belum dijalankan)

1. Di Supabase SQL Editor pada target yang disepakati, jalankan isi
   `sql/checkins_preflight.sql`. Script read-only, hanya mengeluarkan metadata.
   Jangan menyalin isi .env/connection strings/API settings ke hasil audit.
2. Hentikan jika schema chatbot sudah ada, prerequisite tidak ada, RLS profil
   tidak sesuai, role authenticated mewarisi elevated role, atau ownership belum
   disetujui. Jangan menghapus schema yang sudah ada supaya migrasi bisa berjalan.
   Schema terpisah tidak menghilangkan akses postgres/superuser/BYPASSRLS.
3. Tinjau migrasi `migrations/202611040001_checkins.sql` bersama. Revokasi hanya
   pada objek baru, tanpa mengubah default ACL global atau objek website. Tetap
   tinjau memberships/effective grants, termasuk service_role; jangan menganggap
   service_role terisolasi hanya karena RLS aktif.
4. Setelah persetujuan penerapan dan backup siap, koordinator menjalankan migrasi
   utuh. BEGIN/COMMIT, lock timeout dan advisory lock melindungi penerapan ini;
   error menyebabkan rollback, bukan melanjutkan sebagian statement secara manual.
   Migrasi sengaja gagal jika schema sudah ada, termasuk ketika diulang.
5. Jalankan `sql/checkins_verify.sql` read-only dengan operator yang berhak.
   Harapan authenticated: schema_usage/select/insert_mood/update_mood true;
   insert_id/change_created_at/delete/read_ledger/call_trigger_function false.
   Harapan anon dan service_role: semua kolom privilege pada script false.
   Bila hasil berbeda, periksa memberships/ownership sebelum membuka traffic.
6. Pemilik project menambahkan `chatbot` pada **Exposed schemas** Data API tanpa
   menghapus public/schema existing. Jangan menyalin contoh GRANT ALL atau membuka
   anon, ledger dan fungsi. Tidak mengubah global Auth settings/RLS website.
7. Restart backend lokal. Buka /docs: GET/POST /checkins tersedia.
8. Jalankan test live di bawah, hanya dengan dua akun sintetis yang disetujui.

## Pengujian live dua akun dan restart

Jangan menjalankan sebelum langkah review/migrasi/exposure selesai. Tool tidak
membuat akun dan tidak memerlukan Secret key. Password diinput tersembunyi.
Pilih tanggal khusus uji yang kosong pada **kedua** akun; tool berhenti sebelum
menulis jika salah satunya terisi. Contoh tanggal sengaja jauh dari check-in nyata.

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.verify_checkins --date 2000-01-01
```

Menguji token kosong/palsu, simpan kedua akun, baca ulang, ganti mood/note tanpa
duplikat, validasi, pembacaan langsung Data API milik sendiri, larangan membaca
akun lain dan larangan POST dengan user_id akun lain melalui Data API. Tidak
mencetak JWT, UUID, catatan, password atau detail upstream. Tool hanya memakai
dua alamat akun sintetis tetap; jangan menggantinya dengan akun peserta nyata.

Sesudah sukses, hentikan dan nyalakan backend lagi di terminal server dengan
perintah Uvicorn pada README. Kemudian di terminal pengujian:

```powershell
& '.\.venv\Scripts\python.exe' -B -m tools.verify_checkins --date 2000-01-01 --verify-only
```

Mode verify-only tidak menulis check-in; login masih membuat sesi Supabase Auth.
Ia membuktikan data final masih terbaca setelah restart dan Data API tetap
memisahkan akses. Jika tes sebelumnya berhenti sebagian, periksa tahap yang gagal;
jangan mencoba menghapus data atau menimpa tanggal tersebut otomatis.

Pengujian tambahan pada target uji dengan persetujuan pemilik akun/database:

- Dua POST bersamaan milik satu akun/tanggal: satu baris, nilai akhir salah satu
  payload sah; ID sama. Test MockTransport bukan bukti constraint/concurrency DB.
- Profil nonaktif/non-PARTICIPANT: backend dan akses langsung tidak mendapat
  akses baca/tulis. Jangan mengubah role/status pengguna nyata untuk tes.
- Direct PATCH mengganti owner/date harus gagal; DELETE harus ditolak; field
  id/created_at/updated_at dari klien tidak boleh ditulis. RLS UPDATE dapat
  menghasilkan 200 [] untuk baris tak terlihat; verifikasi nilai kedua akun.
- Gangguan koneksi/timeout: response aman, tidak ada auto retry/duplikasi, nilai
  dicek kembali setelah koneksi pulih. Jangan mengganggu layanan produksi.
- Flutter: login/refresh/logout Supabase, Authorization pada API_BASE_URL,
  loading/error/empty, emoji, catatan dihapus, pergantian akun dan pergantian hari.

## Pemulihan

Jika penerapan SQL gagal sebelum COMMIT, rollback transaksi. Jika sesudah COMMIT
tetapi belum lolos tes, hentikan pemakaian endpoint check-in dan pulihkan versi
backend sebelumnya melalui perubahan terkontrol; endpoint /me tetap kompatibel.
Jangan DROP SCHEMA CASCADE atau menghapus baris pengguna. Penarikan exposure schema
baru hanya oleh pemilik project sesudah memeriksa konsumen lain. Untuk perubahan
data/DDL yang telah dipakai, siapkan migrasi perbaikan dan strategi pemulihan backup
yang ditinjau; belum ada destructive rollback otomatis.

## Batas bukti saat ini

Verifikasi lokal 4 November 2026: 196 tests lulus dengan `python -B -m pytest -W
error`, mencakup seluruh 75 test /me sebelumnya; pip check bersih. Smoke test
Uvicorn pada port sementara dengan konfigurasi sintetis juga lulus: docs/OpenAPI
200, /me dan GET/POST /checkins tanpa token 401, body oversized 413. Server uji
dihentikan; server pengguna tidak diubah. Tidak ada koneksi Supabase pada tes ini.

Pengujian lokal memakai MockTransport, bukan PostgreSQL/PostgREST nyata. Mesin
audit tidak memiliki PostgreSQL/Docker lokal yang ditemukan. Sintaks/semantik
migrasi, effective grants, RLS nyata dan persistence sesudah restart masih perlu
dibuktikan pada target uji yang disetujui. Pengujian live profil sebelumnya bukan
bukti bahwa tabel check-in sudah tersedia. Belum ada deployment atau klaim siap
produksi; HTTPS publik, rate limiting, retention/deletion dan integrasi Flutter
merupakan pekerjaan lanjutan.

Referensi primer:
- https://docs.postgrest.org/en/stable/references/api/tables_views.html#upsert
- https://docs.postgrest.org/en/stable/references/api/schemas.html
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/api/securing-your-api
