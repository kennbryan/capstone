/// Builds the psychologist WhatsApp link.
///
/// Only a phone number and a generic message are accepted, so no report,
/// chat, or personal data can ever end up in the URL.
abstract final class WhatsAppLink {
  /// `https://wa.me/{digits}?text={message}`, or null when [number] has no
  /// digits (the WhatsApp button is then hidden).
  static Uri? build({required String? number, required String message}) {
    final digits = number?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return null;
    return Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
  }
}
