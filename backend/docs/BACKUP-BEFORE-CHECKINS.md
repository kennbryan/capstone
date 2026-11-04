# Backup sebelum migrasi check-in

Status saat persiapan: backup nyata **belum dibuat**, migrasi **belum dijalankan**.
User meminta backup baru; informasi backup lama pada repo website adalah catatan
historis, bukan bukti bahwa arsip/kunci pemulihannya tersedia pada mesin ini.

## Yang disiapkan

Client PostgreSQL 17.11 portabel dari EDB (tautan distribusi resmi PostgreSQL)
dan age 1.3.2 dari rilis upstream. Disimpan pada `backend/.backup-tools/`, tidak
menambah dependency aplikasi, tidak memasang service PostgreSQL atau mengubah
PATH sistem. ZIP age diverifikasi terhadap digest rilis upstream; package EDB
diunduh melalui HTTPS resmi dan checksum dicatat, tanpa klaim verifikasi signature
atau checksum vendor independen. Hash setiap executable/DLL diperiksa sebelum backup.

Script `tools/backup_database.py` hanya melakukan export read-only. Tidak membaca
.env website/aplikasi, mengubah password/grants, menjalankan migrasi/restore,
mengubah pengaturan SSL global, atau mengunggah data.

## Sebelum menjalankan

1. Koordinasikan agar tim tidak mengubah struktur/role selama backup.
2. Di project Supabase yang sama, klik **Connect**, pilih Direct atau Session
   pooler port **5432**, salin URI. Gunakan Session bila koneksi langsung tidak
   terjangkau pada jaringan IPv4. Jangan memakai transaction pooler port 6543.
   URI boleh tetap berisi `[YOUR-PASSWORD]`; password dimasukkan terpisah.
3. Di **Database Settings → SSL Configuration**, unduh sertifikat CA database.
   Ini sertifikat publik, bukan private key atau API key. Simpan lokal dan ingat
   path-nya; script menggabungkannya dengan CA publik certifi, lalu memakai
   `sslmode=verify-full`. Jangan menurunkan verifikasi jika sertifikat gagal.
4. Password **database** sudah diketahui user. Jangan reset jika lupa tanpa
   koordinasi: perubahan dapat memutus koneksi website. Publishable/Secret key
   bukan password database dan tidak diperlukan untuk backup ini.
5. Jalankan melalui PowerShell privat interaktif. Input credential disembunyikan;
   script menolak terminal noninteraktif. Jangan mengirim credential, passphrase,
   isi arsip/dekripsi atau tangkapan layar prompt rahasia ke chat.

## Perintah

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.backup_database
```

Input berurutan: URI tersembunyi, password database tersembunyi, path sertifikat
CA publik, lalu passphrase backup dan konfirmasinya di prompt age. Gunakan
passphrase kuat/unik, jangan kosong. Simpan di tempat privat yang dapat diakses
terpisah dari arsip/laptop. Setelah export, age meminta passphrase yang sama
untuk verifikasi. Jangan menggunakan transcript/rekaman terminal untuk langkah ini.

## Hasil dan cakupan

Folder baru eksklusif:
`backend/private-backups/before-checkins-<UTC>/`. Folder tools dan backup diabaikan
Git; tidak ada upload otomatis. Hasil:

- `database.zip.age`: ZIP terenkripsi format age, berisi `database.dump` custom
  PostgreSQL, `roles.sql` tanpa password role, dan `metadata.json`.
- `verification.json`: status, ukuran, SHA-256 ciphertext, hasil verifikasi dan
  penegasan restore/migrasi/upload belum dilakukan; tidak memuat credential/row.

pg_dump mengekspor seluruh objek/data yang dapat di-dump dengan akses operator,
tanpa filter schema, --no-owner atau --no-acl. Scope meliputi data public/Auth,
trigger Auth kustom, fungsi, policy/RLS, ownership/grants dan ledger website yang
berada dalam database. Role/membership dan metadata database dicatat terpisah.
Default treatment extension PostgreSQL tetap berlaku: distribusi extension dan
baseline managed Supabase harus disediakan pada target pemulihan yang kompatibel.

pg_dump memakai snapshot konsisten untuk database; metadata/roles dibaca terpisah.
Script membandingkan catalog sebelum/sesudah dan berhenti jika berbeda; ini tidak
menggantikan koordinasi DDL dan tidak mengunci seluruh perubahan data website.
Koneksi dibatasi source project dan database `postgres`, readonly, TLS verify-full.
`backend_connection_ssl` pada metadata mencatat observasi koneksi backend; pada
pooler observasi itu berbeda dari sertifikat koneksi client→pooler yang diverifikasi.

Output pg_dump langsung masuk ZIP pada pipe ke age. Tidak ada dump/roles/metadata
plaintext yang sengaja ditulis ke disk. Buffer dan password tetap ada dalam RAM;
enkripsi arsip tidak menjamin perlindungan pagefile/hibernation/crash dump atau
mesin yang sudah terkompromi. Tidak mengubah konfigurasi OS untuk tugas ini.

Database yang dilaporkan >512 MiB ditolak oleh desain verifikasi in-memory ini;
gunakan rancangan streaming untuk database lebih besar, jangan memperkecil scope
tanpa review. Diagnostic native disembunyikan; exit gagal/warning tidak dianggap
backup sukses. Arsip parsial tetap dipertahankan tetapi tidak berstatus verified.

Tidak termasuk: byte file Supabase Storage, konfigurasi Auth/OAuth/SMTP/platform,
signing keys di luar database, secret konfigurasi aplikasi dan password role.
Backup database bukan backup seluruh project/platform. Jika Storage dipakai,
rencanakan salinan objek tersendiri sebelum perubahan yang menyentuh Storage.

## Verifikasi dan pemulihan

Script mendekripsi ke memori, memeriksa autentikasi age, ZIP CRC, hash isi, header
PGDMP, objek wajib public/Auth/trigger/policy/ledger, lalu menjalankan pg_restore
--list dan render SQL offline ke NUL. Tidak membuka koneksi untuk restore.
Status sukses: `ENCRYPTED_LOCAL_BACKUP_VERIFIED_NOT_RESTORED`.

Verifikasi ulang arsip yang ada, tanpa koneksi database:

```powershell
& '.\.venv\Scripts\python.exe' -B -m tools.backup_database --verify '<path lengkap database.zip.age>'
```

**Parsing arsip dan hash bukan bukti restore database berhasil.** Uji restore
memerlukan target Supabase/PostgreSQL beserta extension yang kompatibel, terisolasi
dari source, dengan peninjauan managed roles/objects. Tidak pernah melakukan
restore ke project asal sebagai pengujian. Authorization backup tidak menjadi
authorization restore atau migrasi.

Simpan salinan ciphertext dan verification.json pada tempat independen yang
disetujui pemilik data, lalu bandingkan SHA-256 hasil salinan. Tidak ada upload
cloud atau salinan di luar folder tersebut dalam tugas persiapan ini. Jangan
mengirim arsip nyata ke chat/Git. Pengelolaan off-device dan uji restore belum
terverifikasi sampai benar-benar dilakukan dan dilaporkan.

Verifikasi persiapan lokal 4 November 2026: tools portabel berhasil dijalankan;
uji native ZIP pipe → age → dekripsi autentik → ZIP CRC menggunakan data sintetis
lulus. Seluruh suite backend termasuk pemeriksaan backup lulus 224 tests dengan
warnings sebagai error; pip check bersih. Ini bukan bukti export/restore nyata.

Referensi primer:

- https://www.postgresql.org/docs/current/app-pgdump.html
- https://www.postgresql.org/download/windows/
- https://www.enterprisedb.com/download-postgresql-binaries
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/ssl-enforcement
- https://github.com/FiloSottile/age
