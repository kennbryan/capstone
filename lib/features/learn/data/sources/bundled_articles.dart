import 'package:msu_wellbeing/features/learn/data/models/article_dto.dart';

// Article content for the "Materi" section. It ships inside the app (no
// backend endpoint), so Materi always has real content, even offline.
//
// The text is general, non-clinical psychoeducation. It never labels a
// condition and always points to help when things feel too heavy.
// TODO(DKMSU): set `reviewed: true` and `reviewerName` only after an MSU
// psychologist has actually reviewed each article.

const _help = '''
## Kapan perlu bantuan
Jika perasaan berat ini bertahan lebih dari dua minggu, membuat kamu sulit menjalani kegiatan sehari-hari, atau muncul pikiran untuk menyakiti diri, jangan menunggu. Hubungi psikolog MSU lewat menu Chat, layanan Healing119 (telepon 119 lalu tekan 8), atau 112 dalam keadaan darurat.
''';

/// The articles bundled with the app (two per topic).
const List<ArticleDto> bundledArticles = [
  ArticleDto(
    id: 'art_01',
    title: 'Mengelola stres akademik',
    topic: 'kuliah',
    readingMinutes: 4,
    body: '''
Tugas yang menumpuk, ujian, dan tenggat yang berdekatan adalah sumber stres yang dialami banyak mahasiswa. Sedikit tekanan bisa membuat kita lebih fokus. Namun, jika berlangsung terus-menerus, stres dapat mengganggu tidur, nafsu makan, dan konsentrasi.

## Tanda yang perlu diperhatikan
- Sulit tidur atau sering terbangun karena memikirkan tugas.
- Mudah lelah, tegang di bahu, atau sakit kepala.
- Sulit fokus dan makin sering menunda.
- Mudah tersinggung atau ingin menarik diri.

## Langkah kecil yang bisa dicoba
- Tulis semua tugas, lalu pecah setiap tugas menjadi langkah yang bisa selesai dalam satu duduk.
- Urutkan berdasarkan tenggat dan bobot nilainya. Kerjakan **satu** hal dulu.
- Belajar dalam blok 25 menit dengan jeda 5 menit. Setelah empat blok, ambil jeda lebih panjang.
- Matikan notifikasi saat blok fokus. Berpindah-pindah tugas justru menguras energi.
- Jaga hal dasar: tidur cukup, makan teratur, minum air, dan bergerak ringan 20–30 menit.
- Jika tenggat terasa mustahil, bicarakan dengan dosen sejak awal, bukan di menit terakhir.

## Ubah cara bicara pada diri sendiri
Kalimat "aku harus sempurna" membuat beban terasa lebih berat. Coba ganti dengan "aku kerjakan sebaik yang aku bisa hari ini". Kemajuan kecil tetap kemajuan.
$_help''',
  ),
  ArticleDto(
    id: 'art_02',
    title: 'Rutinitas tidur yang menenangkan',
    topic: 'tidur',
    readingMinutes: 4,
    body: '''
Tidur membantu tubuh pulih, menjaga suasana hati, dan memperkuat ingatan atas hal yang baru dipelajari. Kebanyakan orang dewasa membutuhkan sekitar 7–9 jam tidur setiap malam.

## Kebiasaan yang membantu
- **Bangun di jam yang sama setiap hari**, termasuk akhir pekan. Jam bangun yang teratur adalah dasar ritme tidur.
- Dapatkan cahaya matahari pagi beberapa menit setelah bangun.
- Batasi kopi, teh pekat, dan minuman berenergi setelah siang hari. Efek kafein bisa bertahan berjam-jam.
- Jauhkan layar 30–60 menit sebelum tidur, atau setidaknya redupkan dan matikan notifikasinya.
- Buat kamar gelap, sejuk, dan tenang. Gunakan tempat tidur untuk tidur, bukan untuk mengerjakan tugas.
- Jika perlu tidur siang, cukup 20–30 menit dan sebelum sore.

## Rutinitas sebelum tidur
Lakukan kegiatan tenang yang sama setiap malam, misalnya berwudu atau mandi air hangat, membaca ringan, berdoa sesuai keyakinanmu, atau latihan Napas tenang di aplikasi ini. Rutinitas yang konsisten memberi sinyal pada tubuh bahwa saatnya beristirahat.

## Jika belum bisa tidur
Jangan memaksa. Jika sudah sekitar 20 menit berbaring dan masih terjaga, bangun sebentar, lakukan kegiatan tenang di cahaya redup, lalu kembali ke tempat tidur saat mulai mengantuk. Hindari menatap jam berulang kali.
$_help''',
  ),
  ArticleDto(
    id: 'art_03',
    title: 'Mengenali rasa cemas',
    topic: 'kecemasan',
    readingMinutes: 4,
    body: '''
Cemas adalah respons alami tubuh saat menghadapi hal yang tidak pasti atau terasa mengancam, misalnya sebelum presentasi atau saat menunggu hasil ujian. Rasa cemas yang wajar justru membantu kita bersiap.

## Seperti apa rasanya
- Jantung berdebar dan napas menjadi cepat atau pendek.
- Otot tegang, tangan dingin, atau perut tidak nyaman.
- Pikiran berputar pada "bagaimana kalau..." dan sulit berhenti.

## Cara menenangkan diri
- **Perlambat napas.** Tarik napas sekitar 4 hitungan, lalu hembuskan lebih panjang, sekitar 6 hitungan. Hembusan yang panjang membantu tubuh lebih rileks.
- **Kembali ke saat ini (5-4-3-2-1).** Sebutkan 5 hal yang kamu lihat, 4 yang bisa kamu sentuh, 3 yang kamu dengar, 2 yang kamu cium, dan 1 yang kamu rasakan.
- **Beri nama perasaanmu.** Mengatakan "aku sedang cemas" membantu memberi jarak dari perasaan itu.
- **Pisahkan yang bisa dan tidak bisa kamu kendalikan.** Fokuskan tenaga pada langkah kecil yang ada di tanganmu.
- **Sediakan "waktu khawatir"** sekitar 15 menit sehari untuk menuliskan kekhawatiran. Di luar waktu itu, tunda pikiran cemas sampai jadwalnya.

Cemas perlu perhatian lebih jika terasa berlebihan dibanding situasinya, sulit dikendalikan, atau membuatmu menghindari banyak hal penting.
$_help''',
  ),
  ArticleDto(
    id: 'art_04',
    title: 'Menjaga hubungan yang sehat',
    topic: 'hubungan',
    readingMinutes: 4,
    body: '''
Hubungan dengan keluarga, teman, pasangan, maupun rekan organisasi sangat memengaruhi kesejahteraan kita. Hubungan yang sehat membuat kita merasa aman, dihargai, dan bebas menjadi diri sendiri.

## Ciri hubungan yang sehat
- Saling menghormati, termasuk saat berbeda pendapat.
- Jujur dan bisa dipercaya.
- Batasan masing-masing dihargai.
- Ada ruang untuk kegiatan dan pertemanan lain.

## Berkomunikasi dengan lebih baik
- Gunakan kalimat "aku": "Aku merasa sedih ketika rencana kita dibatalkan mendadak. Aku berharap bisa dikabari lebih awal."
- Dengarkan untuk memahami, bukan untuk segera membalas. Ulangi dengan kata-katamu sendiri apa yang kamu tangkap.
- Pilih waktu yang tenang untuk membicarakan hal penting.
- Saat emosi memuncak, minta jeda sejenak dan sepakati kapan akan melanjutkan.

## Menetapkan batasan
Kamu boleh berkata "tidak" tanpa harus merasa bersalah. Batasan bukan tanda tidak peduli, melainkan cara menjaga hubungan tetap sehat untuk kedua pihak.

## Tanda hubungan yang tidak sehat
Mengontrol berlebihan, mengancam, merendahkan, memaksa, atau melakukan kekerasan fisik maupun seksual bukan bagian dari hubungan yang sehat. Jika kamu mengalaminya, ceritakan pada orang yang kamu percaya, hubungi layanan pendampingan di kampusmu, atau 112 jika kamu dalam bahaya.
$_help''',
  ),
  ArticleDto(
    id: 'art_05',
    title: 'Jeda sejenak saat penat',
    topic: 'stres',
    readingMinutes: 3,
    body: '''
Bekerja atau belajar berjam-jam tanpa henti membuat pikiran lelah dan fokus menurun. Jeda singkat bukan tanda malas. Jeda membantu kita kembali dengan kepala yang lebih jernih.

## Jeda 5 menit yang bisa dicoba
- **Napas tenang:** tarik napas perlahan lewat hidung, hembuskan lebih panjang lewat mulut, ulangi beberapa kali.
- **Regangkan tubuh:** putar bahu, regangkan leher dan punggung, lalu berdiri dan berjalan sebentar.
- **Istirahatkan mata:** setiap 20 menit di depan layar, lihat benda yang jauh (sekitar 6 meter) selama 20 detik.
- **Minum air** dan makan camilan sehat jika sudah lama tidak makan.
- **Tenangkan hati:** berdoa atau berzikir sesuai keyakinanmu, atau tuliskan tiga hal yang kamu syukuri hari ini.

## Jadikan kebiasaan
Pasang pengingat jeda setiap 60–90 menit. Saat jeda, hindari langsung membuka media sosial, karena sering kali justru tidak membuat pikiran beristirahat.
''',
  ),
  ArticleDto(
    id: 'art_06',
    title: 'Mengatur waktu belajar tanpa memaksa diri',
    topic: 'kuliah',
    readingMinutes: 4,
    body: '''
Mengatur waktu bukan berarti mengisi setiap jam dengan belajar. Tujuannya adalah membagi energi dengan bijak agar tugas selesai tanpa mengorbankan istirahat.

## Rencanakan mingguan
Setiap awal pekan, lihat jadwal kuliah, tenggat, dan kegiatan lain. Tentukan dua sampai tiga prioritas utama untuk minggu itu.

## Blok waktu yang realistis
- Tetapkan blok belajar di jam ketika kamu paling segar.
- Perkirakan durasi tugas, lalu tambahkan waktu cadangan. Tugas hampir selalu memakan waktu lebih lama dari dugaan.
- Sisakan waktu kosong di jadwal untuk hal tak terduga dan istirahat.

## Melawan kebiasaan menunda
- **Aturan dua menit:** jika sebuah langkah bisa selesai dalam dua menit, kerjakan sekarang.
- Mulai dari langkah paling kecil, misalnya membuka dokumen dan menulis satu kalimat.
- Kerjakan di tempat yang minim gangguan dan simpan ponsel di luar jangkauan.

## Hindari belajar semalam suntuk
Begadang sebelum ujian membuat tubuh lelah dan mengurangi kemampuan mengingat. Tidur membantu otak menyimpan apa yang sudah dipelajari, sehingga belajar sedikit demi sedikit setiap hari lebih efektif.

## Hargai kemajuan
Tandai tugas yang selesai dan beri jeda atau hadiah kecil untuk dirimu. Kemajuan yang konsisten lebih berarti daripada kesempurnaan.
''',
  ),
  ArticleDto(
    id: 'art_07',
    title: 'Saat panik datang tiba-tiba',
    topic: 'kecemasan',
    readingMinutes: 3,
    body: '''
Serangan panik adalah lonjakan rasa takut yang datang tiba-tiba dan disertai sensasi tubuh yang kuat, misalnya jantung berdebar kencang, sesak, gemetar, pusing, atau merasa akan kehilangan kendali. Biasanya rasa ini mencapai puncak dalam beberapa menit, lalu perlahan mereda. Rasanya sangat menakutkan, tetapi sensasi panik itu sendiri tidak membahayakan.

## Yang bisa dilakukan saat itu juga
- Katakan pada diri sendiri: "Ini rasa panik. Ini akan berlalu."
- Duduk jika bisa, dan rasakan kakimu menapak di lantai.
- Perlambat napas, dengan hembusan lebih panjang dari tarikan.
- Gunakan teknik 5-4-3-2-1 untuk kembali ke saat ini.
- Pegang benda yang dingin atau basuh wajah dengan air.
- Jangan melawan sensasinya. Biarkan datang dan pergi seperti ombak.

## Setelah mereda
Beri dirimu waktu untuk beristirahat. Tuliskan apa yang terjadi sebelumnya untuk membantu mengenali pemicunya.

## Penting
Jika nyeri dada atau sesak napas terasa baru, berbeda dari biasanya, atau tidak kunjung mereda, segera periksakan diri ke fasilitas kesehatan atau hubungi 112. Jika panik datang berulang kali, bicarakan dengan psikolog.
$_help''',
  ),
  ArticleDto(
    id: 'art_08',
    title: 'Saat pikiran sulit diam sebelum tidur',
    topic: 'tidur',
    readingMinutes: 3,
    body: '''
Begitu lampu dimatikan, pikiran justru sibuk memutar ulang kejadian hari ini atau mencemaskan esok. Ini pengalaman yang sangat umum.

## Kosongkan pikiran di atas kertas
Sekitar satu jam sebelum tidur, tuliskan semua yang ada di kepala: tugas, kekhawatiran, atau ide. Lalu tulis satu langkah kecil untuk besok. Pikiran lebih mudah tenang saat tahu semuanya sudah "tersimpan".

## Relaksasi otot bertahap
Sambil berbaring, kencangkan satu kelompok otot selama sekitar 5 detik, lalu lepaskan selama 10 detik. Mulai dari kaki, betis, paha, perut, tangan, bahu, hingga wajah. Rasakan bedanya saat otot rileks.

## Alihkan dengan lembut
- Bayangkan tempat yang menenangkan secara detail: suara, warna, dan suhunya.
- Dengarkan suara tenang seperti hujan atau ombak dengan volume pelan. Fitur Suara tenang di aplikasi ini bisa membantu.
- Berdoa atau berzikir dengan perlahan sesuai keyakinanmu.

## Jika tetap terjaga
Jangan memaksa tidur. Bangun sebentar ke ruangan lain dengan cahaya redup, lakukan kegiatan yang membosankan, dan kembali saat mengantuk.
$_help''',
  ),
  ArticleDto(
    id: 'art_09',
    title: 'Saat merasa kesepian',
    topic: 'hubungan',
    readingMinutes: 3,
    body: '''
Rasa kesepian bisa muncul walaupun kita dikelilingi banyak orang, terutama saat merantau, memasuki lingkungan baru, atau melewati masa sulit. Kesepian bukan kegagalan. Ia sinyal bahwa kita butuh terhubung.

## Langkah kecil untuk terhubung
- Hubungi satu orang hari ini, cukup dengan pesan singkat atau telepon sebentar.
- Ikuti kegiatan yang kamu minati, misalnya unit kegiatan mahasiswa, kajian, atau kegiatan sosial di MSU.
- Jadwalkan pertemuan rutin, seperti makan bersama sekali seminggu.
- Menjadi relawan memberi rasa berarti sekaligus kesempatan berkenalan.

## Kualitas lebih penting dari jumlah
Satu atau dua hubungan yang hangat sering kali lebih berarti daripada banyak kenalan. Beranilah sedikit lebih terbuka tentang apa yang kamu rasakan pada orang yang kamu percaya.

## Ramah pada diri sendiri
Saat sendiri, isi waktu dengan hal yang menyenangkan dan merawat diri. Bicaralah pada dirimu seperti kamu menghibur sahabat.
$_help''',
  ),
  ArticleDto(
    id: 'art_10',
    title: 'Mengenali stres yang menumpuk',
    topic: 'stres',
    readingMinutes: 4,
    body: '''
Stres adalah reaksi wajar terhadap tuntutan hidup. Masalah muncul ketika stres datang terus-menerus tanpa sempat dipulihkan, sehingga perlahan menumpuk.

## Tanda yang sering muncul
- **Tubuh:** lelah berkepanjangan, sakit kepala, otot tegang, perubahan pola makan atau tidur.
- **Perasaan:** mudah marah, cemas, sedih, atau merasa kewalahan.
- **Pikiran:** sulit berkonsentrasi, mudah lupa, banyak berpikir negatif.
- **Perilaku:** menarik diri, menunda pekerjaan, atau berlebihan bermain gawai.

## Langkah merawat diri
- **Kenali pemicunya.** Catat kapan rasa tertekan muncul dan apa yang terjadi sebelumnya.
- **Kurangi beban jika bisa.** Belajar menolak dengan sopan atau meminta bantuan.
- **Bergerak.** Jalan kaki, bersepeda, atau olahraga ringan membantu menurunkan ketegangan.
- **Jaga tidur dan makan.** Keduanya adalah fondasi daya tahan terhadap stres.
- **Bercerita.** Berbagi dengan orang yang dipercaya membuat beban terasa lebih ringan.
- **Sisihkan waktu untuk hal yang menenangkan**, seperti ibadah, hobi, atau latihan relaksasi.
$_help''',
  ),
];
