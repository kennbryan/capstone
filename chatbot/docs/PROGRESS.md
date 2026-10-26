# Laporan Progress Bagian AI: Chatbot Hibrida

| | |
|---|---|
| Proyek | Aplikasi Mobile Pendamping Well-being dengan Chatbot Hibrida dan Akses Psikolog Terintegrasi (MSU Telkom University) |
| Bagian | Layanan AI (chatbot hibrida) |
| Penanggung jawab | Marshall Rasendria Mahendra |
| Tanggal | 22 Oktober 2026 |
| Status | Prototype layanan AI berjalan dan sudah dievaluasi awal. Belum terintegrasi dengan mobile dan backend utama. |

## 1. Ringkasan

Layanan AI sudah berbentuk prototype yang dapat dijalankan sebagai layanan terpisah (FastAPI). Fitur yang tersedia:

- triase risiko berlapis;
- rute krisis dengan template tetap;
- jawaban berbasis materi terkurasi (RAG) beserta sumbernya;
- saran aktivitas dari katalog;
- memori personal per pengguna;
- draft ringkasan untuk psikolog.

Layanan juga dilengkapi halaman demo mobile bergaya iOS, 46 unit test, dan evaluasi end-to-end terhadap 45 skenario percakapan. Halaman demo memuat fitur berikut, dan dapat dipasang di aplikasi melalui WebView:

- tombol *Help* yang selalu terlihat;
- kartu bantuan untuk pesan berisiko;
- latihan napas terpandu;
- draft ringkasan dengan saklar persetujuan;
- halaman memori.

## 2. Keputusan dosen dan penerapannya

| No | Pertanyaan | Jawaban dosen | Penerapan pada rancangan |
|---|---|---|---|
| 4 | Psikolog dan prosedur bantuan | Bebas mencari rujukan yang baik di internet | Info bantuan memakai Healing119.id dari Kemenkes (119 ekstensi 8, 24 jam, gratis), nomor darurat 112, IGD terdekat, dan chat psikolog di aplikasi. Template krisis disusun mengikuti prinsip *psychological first aid* WHO (lihat, dengar, hubungkan). Data Layanan Konseling Telkom University dicatat dengan status belum terverifikasi, sehingga tidak tampil di template krisis. |
| 5 | Peninjau dan sumber materi | Bebas mencari sumber yang baik di internet | *Knowledge base* berisi 12 materi dari WHO (*fact sheet* dan *Doing What Matters in Times of Stress*), Kemenkes (Healing119.id dan artikel Ditjen Kesehatan Lanjutan), dan Telkom University. Materi ditulis ulang sebagai ringkasan berbahasa Indonesia, dan setiap materi mencantumkan sumber, versi, dan status terbit. |
| 6 | Model LLM dan biaya | Sementara memakai OpenAI API key pribadi | Layanan memakai `gpt-5.4-mini` untuk respons, `gpt-5.4-nano` untuk triase dan memori, `text-embedding-3-small`, dan `omni-moderation-latest`. Semua model diatur lewat `.env`, sehingga penyedia atau model dapat diganti tanpa mengubah kode. |
| 7 | Retensi data | Riwayat boleh disimpan untuk personalisasi per pengguna | Riwayat sesi dan pesan disimpan. Memori personal (identitas, preferensi, tujuan, pemicu stres, hal yang membantu) diekstraksi otomatis. Pengguna dapat melihat dan menghapus memorinya. |
| 8 | Nada percakapan | Netral dan santai; kutipan tidak perlu diverifikasi | *System prompt* memakai gaya santai dan sopan (aku/kamu), netral, tanpa kutipan ayat atau hadis. Jika pengguna sendiri membahas ibadah, chatbot menanggapi dengan hormat. |

## 3. Arsitektur yang dibangun

Diagram ada di `docs/arsitektur-ai.drawio` dan terdiri dari tiga halaman: arsitektur tingkat tinggi, alur per pesan, dan daftar pemanggilan model AI. Alur per pesan:

1. **Penyimpanan pesan pengguna.** Pesan disimpan lebih dulu, sehingga tetap tercatat walau layanan LLM gagal (skenario U05 pada proposal).
2. **Triase risiko berlapis.** Tiga lapisan berjalan paralel:
   - aturan leksikon bahasa Indonesia, mencakup bahasa gaul dan kata yang disensor (misalnya "b*nuh diri");
   - OpenAI Moderation;
   - *classifier* LLM yang menentukan level risiko, subjek (diri sendiri, orang lain, umum), dan *intent*.

   Penggabungan bersifat *fail-safe*. Jika *classifier* gagal, hasil aturan tetap dipakai. Temuan aturan level *high* hanya dapat diturunkan sampai *moderate*, sehingga pengguna tetap mendapat pertanyaan keamanan dan info bantuan.
3. **Router.** Ada tiga kelompok rute:
   - **Krisis:** risiko tinggi pada diri sendiri. Balasan memakai template tetap yang dapat ditinjau psikolog, bukan teks generatif.
   - **Rapor:** permintaan rapor diarahkan ke menu Rapor. AI tidak menafsirkan skor.
   - **Generatif:** `rag`, `supportive_safety`, `concern_for_other`, dan `medical_boundary`.

   Sesi yang pernah masuk rute krisis tetap berada dalam mode aman pada pesan berikutnya.
4. **RAG.** Pencarian *cosine similarity* pada indeks *embedding* materi. Sumber yang ditampilkan hanya berasal dari hasil *retrieval*, sehingga model tidak dapat mengarang rujukan.
5. **Generator.** Model menghasilkan *structured output* berisi balasan, id sumber, id aktivitas, dan saran ke psikolog.
6. **Output guard.** Pemeriksaan mencakup diagnosis, nama obat atau dosis, detail metode menyakiti diri, dan aksara asing. Jika ditemukan pelanggaran, balasan dibuat ulang satu kali. Jika masih melanggar, dipakai balasan *fallback* yang aman.
7. **Aksi untuk mobile.** Respons dapat memuat aksi berikut:
   - `open_activity`
   - `open_psychologist_chat`
   - `prepare_summary`
   - `call_phone`
   - `open_url`
   - `open_report`
8. **Memory manager** (*background*). Setiap empat pesan, memori personal dan ringkasan sesi diperbarui.
9. **Draft ringkasan untuk psikolog.** Draft hanya dibuat atas permintaan pengguna, berstatus draf, dan tidak pernah dikirim otomatis (KF08).

Audit keamanan disimpan di tabel `safety_events`. Tabel ini hanya mencatat sinyal dan level risiko, tanpa isi pesan (KF10).

## 4. Hasil evaluasi awal

Evaluasi dijalankan dengan `python -m eval.run_eval` memakai API asli pada 22 Oktober 2026. Setiap skenario diuji sebagai sesi baru.

| Metrik | Hasil |
|---|---|
| Ungkapan risiko langsung yang masuk rute krisis | 8/8 |
| Ungkapan risiko tidak langsung yang dieskalasi (minimal *moderate*) | 8/8 |
| Ungkapan ambigu atau hiperbola dengan level dalam rentang yang diterima | 4/4 |
| Pesan biasa yang salah dieskalasi (*false alarm*) | 0/8 |
| Kekhawatiran tentang orang lain yang diarahkan ke panduan mendampingi (bukan template krisis) | 3/3 |
| *Retrieval* materi yang tepat dalam top-4 / peringkat 1 | 14/14 / 14/14 |
| Jawaban yang mengutip materi yang diharapkan | 14/14 |
| *Intent* batasan tepat (diagnosis, obat, rapor, di luar topik, minta psikolog) | 5/5 |
| Pelanggaran *output guard* pada balasan akhir | 0 |
| Latensi rute generatif p50 / p90 | 3,1 detik / 3,7 detik |
| Latensi rute krisis p50 | 1,3 detik |
| Respons dalam batas 15 detik (target proposal) | 45/45 |

Uji manual multi-giliran juga dilakukan. Chatbot mengingat nama panggilan dan kebiasaan yang membantu pengguna pada sesi berikutnya. Draft ringkasan berisi fakta dari pengguna tanpa diagnosis.

**Catatan keterbatasan evaluasi.**

- Skenario masih sedikit (45 kasus) dan disusun oleh pengembang. Pola leksikon juga ditulis oleh orang yang sama. Akibatnya, angka di atas kemungkinan lebih tinggi daripada performa pada pesan pengguna sungguhan.
- Hasil ini belum dapat diartikan bahwa sistem mendeteksi semua situasi berisiko.
- Idiom "tugas numpuk banget, mati aku" masih dinilai *moderate*. Akibatnya, chatbot menanyakan keamanan secara berlebihan. Hal ini dipilih secara sadar (lebih aman daripada terlewat), tetapi perlu dipantau saat uji pengguna.
- Pada uji manual pertama, satu memori hasil ekstraksi berisi kesimpulan yang tidak disampaikan pengguna. Prompt ekstraksi memori sudah diperketat agar hanya menyimpan pernyataan eksplisit. Pada uji ulang dengan percakapan yang sama, keempat memori yang tersimpan sesuai dengan ucapan pengguna.
- Pada evaluasi pertama, satu balasan menyelipkan kata berbahasa Rusia. Kasus ini kini ditangkap *output guard* dan memicu pembuatan ulang balasan.

## 5. Keterkaitan dengan kebutuhan proposal

| Kebutuhan | Status |
|---|---|
| KF03 Chatbot hibrida, sumber tampil saat memakai *retrieval* | Selesai pada sisi layanan |
| KF06 Percakapan menuju aktivitas | Selesai pada sisi layanan dan aplikasi Flutter (lihat bagian 8) |
| KF08 Ringkasan dengan persetujuan | Draft tampil dan dapat diubah di aplikasi. Pengiriman langsung ke psikolog menunggu API chat psikolog. |
| KF09 Akses bantuan dan status layanan | Info bantuan terverifikasi tersedia di setiap respons berisiko |
| KF10 Audit tanpa mengekspos isi chat | `safety_events` hanya menyimpan sinyal |
| Respons chatbot paling lama 15 detik untuk minimal 90% permintaan | Terpenuhi pada lingkungan uji (p90 3,7 detik) |
| U05 Layanan LLM gagal | Pesan tetap tersimpan, balasan *fallback* jelas, dan info bantuan tetap tersedia |

## 6. Rencana berikutnya

1. Menyepakati kontrak API dengan tim mobile dan website: format `user_id`, *service key*, penanganan setiap jenis aksi, dan lokasi penyimpanan chat.
2. Integrasi dengan backend utama. Database dipindahkan ke Postgres bersama cukup dengan mengganti `DATABASE_URL`.
3. Menambah *streaming* respons (SSE) agar balasan terasa lebih cepat di mobile.
4. Memperluas skenario evaluasi bersama orang di luar pengembang, lalu menguji ulang leksikon dan ambang *moderation*.
5. Memasang halaman demo ke aplikasi mobile bersama tim mobile (WebView dan bridge aksi), lalu menambahkan penjelasan penyimpanan data saat pengguna pertama kali memakai chatbot.
6. Memverifikasi kontak dan jadwal Layanan Konseling Telkom University 2026, lalu mengubah statusnya menjadi `verified` bila sudah dikonfirmasi.
7. Mencatat penggunaan token per permintaan untuk memperkirakan biaya sebelum keputusan model jangka panjang.

## 7. Hal yang perlu diketahui tim

- API key OpenAI disimpan hanya di `.env` dan tidak ikut ke repository. Anggota lain perlu mengisi `.env` sendiri berdasarkan `.env.example`.
- Layanan ini tidak melakukan autentikasi pengguna. Backend utama wajib memverifikasi pengguna sebelum meneruskan `user_id`.
- Template krisis (`data/crisis_templates.yaml`) dan prompt (`app/prompts.py`) dipisahkan agar mudah ditinjau. Peninjauan oleh psikolog tetap dianjurkan sebelum uji pengguna.

## 8. Pembaruan 26 Oktober 2026: integrasi dengan aplikasi Flutter

Layanan AI kini dipakai langsung oleh aplikasi Flutter buatan Kenneth (folder `lib/` di repository tim). Halaman demo HTML tidak lagi dipakai, sehingga rencana WebView pada poin 6.5 diganti dengan integrasi *native*.

- **Endpoint khusus aplikasi.** Layanan menambah *router* `/chatbot/*` (`app/mobile_api.py`) yang mengikuti kontrak JSON di `lib/features/chat/data/sources/chat_sources.dart`: key *camelCase*, balasan krisis bertipe `crisis`, dan saran latihan lewat `suggestions`. Endpoint `/v1/*` untuk backend utama tetap ada.
- **Sesi percakapan.** Setiap balasan membawa `conversationId`, lalu aplikasi mengirimkannya kembali pada pesan berikutnya agar konteks dan memori tetap terjaga. Menu "Hapus riwayat chat" juga menghapus sesi di server.
- **Aksi di aplikasi.** Aktivitas `napas-lambat` dan `melepas-pikiran` membuka layar latihan yang sudah ada di aplikasi (*Napas tenang* dan *Lepaskan pikiran*). Aktivitas lain tampil sebagai lembar langkah-langkah beserta sumbernya. Tombol telepon, tautan bantuan, chat psikolog, dan menu Rapor juga sudah berfungsi.
- **Draft ringkasan untuk psikolog (KF08).** Draft tampil di aplikasi, dapat diubah, lalu disalin oleh pengguna. Aplikasi tidak pernah mengirim draft secara otomatis, dan tautan WhatsApp tetap hanya berisi pesan umum.
- **Memori Asisten AI.** Menu baru di Profil untuk melihat dan menghapus memori personal, sesuai keputusan dosen no. 7.
- **Identitas pengguna.** Untuk akun demo aplikasi, layanan menerima token perangkat `demo-session-<userId>`. Akun asli tetap harus melewati backend utama, yang meneruskan `X-User-Id` bersama `X-Service-Key`.

## Sumber yang dipakai

- WHO. Mental health: strengthening our response. https://www.who.int/news-room/fact-sheets/detail/mental-health-strengthening-our-response
- WHO. Depression. https://www.who.int/news-room/fact-sheets/detail/depression
- WHO. Anxiety disorders. https://www.who.int/news-room/fact-sheets/detail/anxiety-disorders
- WHO. Suicide. https://www.who.int/news-room/fact-sheets/detail/suicide
- WHO. (2020). Doing What Matters in Times of Stress: An Illustrated Guide. https://www.who.int/publications/i/item/9789240003927
- WHO. (2011). Psychological First Aid: Guide for Field Workers. https://www.who.int/publications/i/item/9789241548205
- Kemenkes RI. (2025). FAQ Layanan Hotline Healing119.id. https://kesprimkom.kemkes.go.id/assets/uploads/contents/others/FAQ_Cegah_Bunuh_Diri%2C_Dukung_Kesehatan_Jiwa__Kenali_Layanan_Healing119.id.pdf
- Kemenkes RI. (2025). Penting Tidur. https://keslan.kemkes.go.id/read/2539/penting-tidur
- Kemenkes RI. (2023). Stress Management: Kelola Kesulitan Menjadi Kemudahan. https://keslan.kemkes.go.id/view_artikel/2917/stress-management-kelola-kesulitan-menjadi-kemudahan
- Telkom University. (2024). Telkom University Strengthens Student Mental Health Support. https://sdgs.telkomuniversity.ac.id/news/telkom-university-strengthens-student-mental-health-support-through-comprehensive-counseling-services
