import 'package:dio/dio.dart';
import 'package:msu_wellbeing/features/remote_config/data/models/remote_config_dto.dart';

/// Source of the remote config.
abstract interface class RemoteConfigSource {
  Future<RemoteConfigDto> fetch();
}

/// Settings DKMSU controls without an app update.
///
/// **For the backend team** (public, no auth needed; it is called before
/// login, e.g. for the "Daftar di website asesmen" link):
///
/// `GET /config` → 200
/// ```json
/// {
///   "whatsappNumber": "6281234567890",
///   "crisisContacts": [
///     {
///       "label": "Konseling Telkom University",
///       "phone": "0221234567",
///       "description": "Senin–Jumat, 08.00–16.00"
///     }
///   ],
///   "assessmentWebsiteUrl": "https://asesmen.msu.example",
///   "consentVersion": 1
/// }
/// ```
/// - `whatsappNumber`: psychologist WhatsApp, international format without
///   `+`. `null` hides the button ("Layanan psikolog belum tersedia").
/// - `crisisContacts`: extra help lines. If empty or missing, the app shows
///   the verified national lines (Healing119, 112, 118) instead.
/// - `assessmentWebsiteUrl`: must be `https`.
/// - `consentVersion`: raise it when the data terms change; users are then
///   asked to agree again.
///
/// The app caches the last good response and uses it when offline.
class RemoteConfigRemoteSource implements RemoteConfigSource {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<RemoteConfigDto> fetch() async {
    final response = await _dio.get<Map<String, Object?>>('/config');
    return RemoteConfigDto.fromJson(response.data!);
  }
}
