import 'dart:async';
import 'dart:math';

import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/features/assessment/data/models/assessment_report_dto.dart';
import 'package:msu_wellbeing/features/assessment/data/sources/assessment_sources.dart';
import 'package:msu_wellbeing/features/auth/data/models/user_dto.dart';
import 'package:msu_wellbeing/features/auth/data/sources/auth_source.dart';
import 'package:msu_wellbeing/features/chat/data/models/chat_message_dto.dart';
import 'package:msu_wellbeing/features/chat/data/sources/chat_sources.dart';
import 'package:msu_wellbeing/features/checkin/data/models/check_in_dto.dart';
import 'package:msu_wellbeing/features/checkin/data/sources/checkin_sources.dart';
import 'package:msu_wellbeing/features/remote_config/data/models/remote_config_dto.dart';
import 'package:msu_wellbeing/features/remote_config/data/sources/remote_config_source.dart';

// Test doubles for the backend. The app itself has no mock data: these
// stand in for the API so widget and controller tests run offline.

/// Which state a fake source should simulate.
enum MockScenario { data, empty, error, loading }

/// Switches for the fake sources.
class MockSettings {
  const new({
    this.reports = MockScenario.data,
    this.checkins = MockScenario.data,
    this.whatsappDummy = false,
    this.instant = false,
  });

  final MockScenario reports;
  final MockScenario checkins;

  /// When true, the fake config returns a WhatsApp number.
  final bool whatsappDummy;

  /// Skips simulated latency.
  final bool instant;

  Future<void> latency([
    Duration duration = const Duration(milliseconds: 450),
  ]) => instant ? Future<void>.value() : Future<void>.delayed(duration);

  /// Waits, then throws for [MockScenario.error] or never completes for
  /// [MockScenario.loading].
  Future<void> apply(MockScenario scenario) async {
    await latency();
    switch (scenario) {
      case MockScenario.error:
        throw const ApiException(ApiExceptionKind.network);
      case MockScenario.loading:
        await Completer<void>().future;
      case MockScenario.data:
      case MockScenario.empty:
        return;
    }
  }
}

/// `/reports` with two reports.
class AssessmentMockSource implements AssessmentSource {
  const new(this._settings);

  final MockSettings _settings;

  static final _reports = [
    AssessmentReportDto(
      id: 'rpt_002',
      title: 'Rapor Kesejahteraan Diri — Oktober',
      takenAt: DateTime.utc(2026, 10, 14, 3),
      summary:
          'Kamu sedang membawa cukup banyak tuntutan dari perkuliahan. Di sisi '
          'lain, hubunganmu dengan orang-orang terdekat menjadi sumber '
          'dukungan yang berarti.',
      sections: const [
        ReportSectionDto(
          heading: 'Tuntutan akademik',
          body:
              'Beban tugas dan tenggat waktu terasa cukup padat beberapa '
              'minggu terakhir. Jeda singkat dan pembagian waktu yang '
              'realistis bisa membantu.',
          level: 'Perlu perhatian lebih',
        ),
        ReportSectionDto(
          heading: 'Dukungan sosial',
          body:
              'Kamu memiliki teman dan keluarga yang bisa diajak bicara. '
              'Pertahankan kebiasaan saling menyapa ini.',
          level: 'Baik',
        ),
        ReportSectionDto(
          heading: 'Waktu istirahat',
          body:
              'Jam tidurmu bervariasi. Rutinitas sebelum tidur yang tenang '
              'dapat membuat istirahat lebih nyaman.',
          level: 'Cukup',
        ),
      ],
    ),
    AssessmentReportDto(
      id: 'rpt_001',
      title: 'Rapor Kesejahteraan Diri — Juli',
      takenAt: DateTime.utc(2026, 7, 2, 2),
      summary:
          'Secara umum kamu merasa cukup seimbang. Ada beberapa hal kecil '
          'yang bisa dirawat agar tetap nyaman menjalani hari.',
      sections: const [
        ReportSectionDto(
          heading: 'Keseimbangan aktivitas',
          body:
              'Kegiatan kuliah, ibadah, dan waktu luang cukup seimbang. '
              'Tetap sisihkan waktu untuk hal yang kamu sukai.',
          level: 'Baik',
        ),
      ],
    ),
  ];

  @override
  Future<List<AssessmentReportDto>> getReports() async {
    await _settings.apply(_settings.reports);
    return _settings.reports == MockScenario.empty ? const [] : _reports;
  }

  @override
  Future<AssessmentReportDto> getReport(String id) async {
    await _settings.apply(_settings.reports);
    return _reports.firstWhere(
      (report) => report.id == id,
      orElse: () => throw const ApiException(ApiExceptionKind.notFound),
    );
  }
}

/// `/checkins`, in memory, seeded with a few past days (some empty).
class CheckInMockSource implements CheckInSource {
  new(this._settings) {
    if (_store.isEmpty) _seed();
  }

  final MockSettings _settings;
  static final Map<String, CheckInDto> _store = {};

  static void _seed() {
    final today = DateFormatter.dateOnly(DateTime.now());
    const moods = {1: 4, 2: 3, 4: 3, 5: 2, 6: 4};
    moods.forEach((daysAgo, mood) {
      final date = DateFormatter.isoDate(
        today.subtract(Duration(days: daysAgo)),
      );
      _store[date] = CheckInDto(id: 'chk_$date', date: date, mood: mood);
    });
  }

  /// Clears the shared store between tests.
  static void reset() => _store.clear();

  @override
  Future<List<CheckInDto>> getCheckIns({
    required String from,
    required String to,
  }) async {
    await _settings.apply(_settings.checkins);
    if (_settings.checkins == MockScenario.empty) return const [];
    return [
      for (final entry in _store.entries)
        if (entry.key.compareTo(from) >= 0 && entry.key.compareTo(to) <= 0)
          entry.value,
    ];
  }

  @override
  Future<CheckInDto> save({
    required String date,
    required int mood,
    String? note,
  }) async {
    await _settings.latency();
    return _store[date] = CheckInDto(
      id: 'chk_$date',
      date: date,
      mood: mood,
      note: note,
    );
  }
}

/// `/chatbot/messages`: rotates a plain reply, one with sources, and one
/// with suggestions; `#tes-krisis` returns a crisis reply.
class ChatMockSource implements ChatSource {
  new(this._settings, [Random? random]) : _random = random ?? Random();

  final MockSettings _settings;
  final Random _random;

  static const crisisTrigger = '#tes-krisis';
  static int _turn = 0;

  /// Restarts the reply rotation between tests.
  static void reset() => _turn = 0;

  @override
  Future<ChatMessageDto> send(String text) async {
    await _settings.latency(Duration(milliseconds: 600 + _random.nextInt(601)));
    final now = DateTime.now().toUtc();
    final id = 'fake_${now.microsecondsSinceEpoch}';
    if (text.toLowerCase().contains(crisisTrigger)) {
      return ChatMessageDto(
        id: id,
        role: 'assistant',
        type: 'crisis',
        createdAt: now,
        text:
            'Terima kasih sudah memberi tahu. Keselamatanmu sangat penting, '
            'dan kamu tidak harus menghadapinya sendirian. Hubungi bantuan '
            'sekarang, ya.',
      );
    }
    return switch (_turn++ % 3) {
      0 => ChatMessageDto(
        id: id,
        role: 'assistant',
        createdAt: now,
        text:
            'Terima kasih sudah bercerita. Wajar merasa seperti itu. Kalau '
            'mau, ceritakan lebih banyak tentang apa yang paling terasa '
            'berat hari ini.',
      ),
      1 => ChatMessageDto(
        id: id,
        role: 'assistant',
        createdAt: now,
        text:
            'Wajar merasa tertekan saat tugas menumpuk. Materi ini mungkin '
            'bisa membantumu menyusun langkah kecil.',
        sources: const [
          SourceRefDto(articleId: 'art_01', title: 'Mengelola stres akademik'),
        ],
      ),
      _ => ChatMessageDto(
        id: id,
        role: 'assistant',
        createdAt: now,
        text:
            'Bagaimana kalau kita menenangkan diri sejenak? Latihan napas '
            'singkat bisa membantu tubuh terasa lebih rileks.',
        suggestions: const [
          LearnRefDto(kind: 'breathing', title: 'Napas tenang 3 menit'),
        ],
      ),
    };
  }
}

/// `/config`: no campus contacts (so the national lines show), and a
/// WhatsApp number only when [MockSettings.whatsappDummy] is set.
class RemoteConfigMockSource implements RemoteConfigSource {
  const new(this._settings);

  final MockSettings _settings;

  static const dummyWhatsappNumber = '620000000000';

  @override
  Future<RemoteConfigDto> fetch() async {
    await _settings.latency(const Duration(milliseconds: 200));
    return RemoteConfigDto(
      whatsappNumber: _settings.whatsappDummy ? dummyWhatsappNumber : null,
      assessmentWebsiteUrl: 'https://asesmen.example.invalid',
    );
  }
}

/// `/auth/login` rejecting every non-demo account; `/me` returns nothing,
/// so the cached profile is kept.
class FakeAuthSource implements AuthSource {
  const new();

  @override
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  }) => Future.error(
    const ApiException(ApiExceptionKind.unauthorized, statusCode: 401),
  );

  @override
  Future<UserDto?> me() async => null;
}
