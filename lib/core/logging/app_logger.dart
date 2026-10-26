import 'dart:developer' as developer;

import 'package:msu_wellbeing/core/network/api_exception.dart';

/// Logs app events and errors.
///
/// Never pass user content: no chat text, check-in notes, report content,
/// release-thought text, or tokens. Only names, ids, counts, and statuses.
abstract final class AppLogger {
  /// Verbose logging; disabled in `prod` by `main`.
  static bool verbose = true;

  /// Records a named event with optional non-sensitive [data].
  static void event(String name, [Map<String, Object>? data]) {
    if (!verbose) return;
    developer.log(data == null ? name : '$name $data', name: 'msu.event');
  }

  /// Records an error by type only. Error messages can echo user content
  /// (e.g. a `FormatException` quoting stored chat JSON), so they are never
  /// logged. [ApiException] is safe: it carries only a kind and a status.
  static void error(String context, Object error, [StackTrace? stackTrace]) {
    developer.log(
      context,
      name: 'msu.error',
      level: 1000,
      error: error is ApiException ? error : error.runtimeType,
      stackTrace: verbose ? stackTrace : null,
    );
  }
}
