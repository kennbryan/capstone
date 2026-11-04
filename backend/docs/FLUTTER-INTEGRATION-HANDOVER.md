# Integrasi Flutter: login Supabase dan check-in staging

Status 4 November 2026: backend sudah diuji dengan dua akun di Supabase staging.
Dokumen ini kontrak dan urutan pekerjaan integrasi untuk Kenneth (Flutter) dan
Ferdiansyah (backend), bukan klaim bahwa UI Flutter sudah terhubung.
Pengguna memilih Windows desktop atau browser untuk pengujian berikutnya.

## Target dan bukti

- Project staging: `orxbprfixonwdwgjqmpv`.
- Backend pada laptop yang menjalankannya: `http://127.0.0.1:8002`.
- OpenAPI/Swagger: `http://127.0.0.1:8002/docs`.
- `evidence/staging-http-verification.json`: /me dua akun dan baca check-in
  melalui HTTP lulus pada `2026-11-04T16:25:04.229691+00:00`.
- `evidence/staging-checkins-verification.json`: simpan, replace dengan ID sama,
  penghapusan note, validasi dan larangan baca/tulis akun lain lulus melalui
  rute FastAPI dalam proses dengan Data API staging nyata.
- `evidence/staging-checkins-readback.json`: proses baru membaca hasil yang sama.
- POST check-in lewat server HTTP, UI Flutter, refresh sesi Flutter dan deployment
  belum teruji. Pengujian bukan persetujuan penerapan pada database website.

## Kontrak yang dipakai

Login Flutter langsung ke Supabase Auth staging menggunakan email/password dan
publishable key staging. Backend tidak menyediakan `POST /auth/login`.
Ambil access token dari sesi Supabase; panggil backend dengan
`Authorization: Bearer <access-token>`; jangan mengirim refresh token ke backend.
Setelah login, profil aplikasi diambil dari /me; user_metadata bukan sumber role.
Jangan menyalin password/key/token nyata ke dokumen atau repository.

| Endpoint | Request | Respons berhasil |
| --- | --- | --- |
| GET /me | Bearer token | 200 `{id,displayName,email}` |
| GET /checkins | Bearer token; from/to YYYY-MM-DD, inklusif 1–366 hari | 200 array `{id,date,mood,note?}`, urutan tanggal naik; kosong `[]` |
| POST /checkins | Bearer token; JSON `{date,mood,note?}` | 200 satu object `{id,date,mood,note?}` |

ID adalah UUID string. Mood integer 1–5; note opsional maksimal 200 Unicode
code points sesudah trim. POST tanggal sama mengganti mood dan note; note
omitted/null/kosong menghapus note. ID dipertahankan. Date adalah tanggal kalender
aplikasi, bukan hasil konversi ke UTC. User ID tidak boleh disertakan dalam body.
Detail batas request/error: `CHECKINS-ROLLOUT.md` dan OpenAPI.

401 berarti sesi perlu ditangani; 403 berarti akses/profil ditolak; 422 input
tidak valid; 503 gangguan layanan. 408/413/415 tersedia untuk masalah body.
Jangan melakukan auto retry POST check-in setelah timeout: baca tanggal tersebut
lebih dahulu karena commit mungkin sudah terjadi. Catatan privat tidak dilog.

## Perubahan Flutter yang diperlukan

1. **Login dan sesi.** `lib/features/auth/data/sources/auth_source.dart`
   masih memanggil `/auth/login`; `auth_repository_impl.dart` menyimpan token
   tetapi tidak melakukan refresh. Ubah source untuk login Supabase langsung,
   kemudian ambil /me memakai token baru. Pertahankan kontrak domain/controller
   bila memungkinkan; `LoginResponseDto` adalah DTO aplikasi, bukan bentuk mentah
   respons Supabase. `pubspec.yaml` belum menyertakan supabase_flutter.
   SDK Supabase Flutter merupakan rekomendasi integrasi, belum dipasang di tahap ini.
2. **Satu pengelola sesi.** Atur restore, refresh dan logout melalui satu otoritas
   sesi; hindari dua salinan token yang bisa berbeda. Jika memakai SDK, sinkronkan
   peristiwa initialSession/signedIn/tokenRefreshed/signedOut ke Riverpod dan
   penyimpanan aman yang dipilih. Gunakan error handler pada stream auth. Jangan
   menganggap penyimpanan default SDK otomatis sama dengan secure storage saat ini.
   Kegagalan jaringan saat refresh tidak otomatis berarti logout permanen.
3. **Interceptor.** `lib/core/network/dio_client.dart` membaca token dari
   SecureKeys.accessToken; pastikan membaca token terkini setelah refresh, dan
   pembatasan tujuan memakai origin yang disetujui (scheme/host/port).
   Hindari logout dari respons 401 permintaan sesi lama sesudah pengguna berganti
   akun. Interceptor saat ini langsung memberi sinyal logout untuk 401 selain
   `/auth/login`; strategi refresh perlu mengubah perilaku ini secara terkontrol.
4. **State dan error.** `auth_controller.dart` mengendalikan pengguna; check-in
   controller menonton currentUserIdProvider. Pastikan hasil save yang masih
   berjalan milik akun A tidak memperbarui UI sesudah pindah ke B. Ini kebutuhan
   uji, belum dinyatakan sebagai race yang sudah direproduksi.
   `lib/core/network/api_exception.dart` saat ini mengelompokkan 401/403 bersama,
   sedangkan 422 jatuh ke kategori server; sesuaikan pesan/tindakan UI dengan
   kontrak agar penolakan akses dan kesalahan input tidak dianggap password salah.
5. **Check-in.** `checkin_sources.dart` dan `check_in_dto.dart` sudah sesuai bentuk
   dasar endpoint. Gunakan backend staging yang sama dengan project login dan
   `DEMO_LOGIN=false`; token demo bukan sesi Supabase. Uji note dihapus, emoji,
   empty history, loading/error dan hari kalender lokal dari UI.

Nama file di atas relatif terhadap root repository; lokasi lengkap:
`../../lib/features/auth/data/sources/auth_source.dart`,
`../../lib/features/auth/data/auth_repository_impl.dart`,
`../../lib/features/auth/presentation/controllers/auth_controller.dart`,
`../../lib/core/network/dio_client.dart`,
`../../lib/features/checkin/presentation/controllers/checkin_controller.dart`,
`../../lib/features/checkin/data/sources/checkin_sources.dart`,
`../../lib/features/checkin/data/models/check_in_dto.dart`.

## Menjalankan backend dan alamat Flutter

Server staging harus direstart setelah perubahan CORS peluncur ini:

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.serve_staging
```

Masukkan publishable key staging melalui prompt tersembunyi. Binding tetap
loopback port 8002, tanpa membaca .env. CORS hanya pada peluncur staging:
origin `http://localhost:7357` dan `http://127.0.0.1:7357`, GET/POST dengan
Authorization/Content-Type, tanpa cookie credentials. Origin lain tidak diizinkan.
CORS tidak menggantikan autentikasi/RLS. Proses server lama belum memakai perubahan
ini sampai dihentikan dengan Ctrl+C dan dinyalakan kembali oleh operator.

Sesudah source login diperbarui, dari root project dan dengan Flutter SDK yang
sesuai terpasang, konfigurasi API yang sudah tersedia dapat dipakai sebagai berikut:

```powershell
# Windows desktop pada laptop server
flutter run -d windows --dart-define=APP_ENV=dev --dart-define=DEMO_LOGIN=false --dart-define=API_BASE_URL=http://127.0.0.1:8002

# Browser pada laptop server, origin harus memakai port ini
flutter run -d chrome --web-hostname=localhost --web-port=7357 --dart-define=APP_ENV=dev --dart-define=DEMO_LOGIN=false --dart-define=API_BASE_URL=http://127.0.0.1:8002
```

Perintah tersebut belum menambahkan konfigurasi login Supabase yang belum ada
di AppConfig; Kenneth perlu menyediakan konfigurasi URL/publishable key staging
sesuai implementasi auth yang dipilih. Itu bukan perintah uji login yang sudah siap
dipakai pada Flutter saat ini. Jangan memakai secret/service-role key dalam app.
Pada pemeriksaan ini flutter/dart tidak ditemukan di PATH, sehingga perintah build,
analyze dan test Flutter belum dijalankan. SDK di lokasi lain BELUM TERVERIFIKASI.

## Batas fitur ketika menguji aplikasi

`GET /config`, `PUT /consents`, assessment/rapor dan gateway chatbot belum tersedia
di companion backend. Consent repository saat ini menyimpan lokal dan menelan error
sinkronisasi; kegagalan upload tidak membuktikan consent server sudah tercatat.
Remote config mencoba cache; startup guard punya fallback ketika config error.
Jangan menyatakan semua fitur home siap hanya karena check-in sudah berjalan.
Jangan membuat endpoint kosong yang berpura-pura menerima consent atau rapor.
Consent sebelum login juga perlu dibahas bersama perilaku 401 di interceptor.

Untuk Android nantinya, manifest dan network_security_config saat ini menolak HTTP;
alamat/transport Android perlu dirancang terpisah. Pengujian awal dipilih Windows/web.

## Kriteria penerimaan bersama

1. Akun A login lewat UI ke staging, /me benar; salah password ditangani aman.
2. Simpan check-in dari UI pada tanggal uji yang disepakati; baca ulang melalui
   HTTP dan Data API staging, cocok dengan UI. POST HTTP ini belum diuji sebelumnya.
3. Ubah mood/note tanggal sama; satu baris, ID tetap; kosongkan note.
4. Tutup/buka Flutter; sesi dan riwayat dipulihkan dengan benar.
5. Refresh token diuji, termasuk beberapa request bersamaan dan offline sementara.
6. Logout A lalu login B: riwayat A tidak muncul; request A yang terlambat tidak
   mengubah state B. Token kedaluwarsa/nonaktif/akses ditolak diuji terpisah.
7. UI tidak mengirim user_id, tidak mencetak token/note, dan tidak mengulang POST
   otomatis setelah timeout.

Test existing yang perlu dijalankan setelah perubahan Flutter:
`test/core/network/auth_interceptor_test.dart`,
`test/core/config/app_config_test.dart`,
`test/core/router/route_guard_test.dart`,
`test/features/auth/data/demo_accounts_test.dart`,
`test/features/auth/presentation/screens/login_screen_test.dart`,
`test/features/checkin/presentation/controllers/checkin_controller_test.dart`.
Tambahkan cakupan sesi Supabase/refresh dan UI integration untuk kasus di atas;
test existing bukan bukti cakupan auth nyata. Gunakan flutter analyze dan flutter test
setelah SDK/dependency siap. Tidak ada test Flutter yang dinyatakan lulus di laporan ini.

Referensi primer rekomendasi SDK:
- https://supabase.com/docs/reference/dart/auth-signinwithpassword
- https://supabase.com/docs/reference/dart/auth-onauthstatechange

Langkah Ferdiansyah berikutnya sesudah paket integrasi ini: review gateway chatbot
bersama Marshall (verifikasi sesi, ownership percakapan, rate limit, error dan
privasi). Itu belum menjadi bagian dari kontrak check-in yang telah diuji.
