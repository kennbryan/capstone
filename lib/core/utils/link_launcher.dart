import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'link_launcher.g.dart';

/// Opens URLs, phone dialers, and WhatsApp outside the app.
///
/// Only `https` and `tel` links are allowed, so a bad or tampered server
/// value can never open `http`, `intent:`, `file:` or other schemes.
class LinkLauncher {
  const new();

  static const _allowedSchemes = {'https', 'tel'};

  /// Returns false when [uri] is not allowed or nothing could handle it.
  /// The URI is never logged.
  Future<bool> open(Uri uri) async {
    if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      AppLogger.event('link.blocked', {'scheme': uri.scheme});
      return false;
    }
    if (uri.scheme == 'https' && uri.host.isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error, stackTrace) {
      AppLogger.error('link.open.${uri.scheme}', error, stackTrace);
      return false;
    }
  }

  /// Opens the phone dialer with [phone] prefilled. Only digits, `+`, `*`
  /// and `#` are kept.
  Future<bool> dial(String phone) {
    final number = phone.replaceAll(RegExp('[^0-9+*#]'), '');
    if (number.isEmpty) return Future.value(false);
    return open(Uri(scheme: 'tel', path: number));
  }
}

@Riverpod(keepAlive: true)
LinkLauncher linkLauncher(Ref ref) => const LinkLauncher();
