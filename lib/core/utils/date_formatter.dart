import 'package:intl/intl.dart';

/// Date helpers using the Indonesian locale.
abstract final class DateFormatter {
  static const _locale = 'id';

  /// e.g. "22 Oktober 2026".
  static String fullDate(DateTime date) =>
      DateFormat('d MMMM y', _locale).format(date.toLocal());

  /// e.g. "Rabu, 22 Oktober".
  static String heroDate(DateTime date) =>
      DateFormat('EEEE, d MMMM', _locale).format(date.toLocal());

  /// e.g. "22 Okt 2026, 13.00".
  static String dateTime(DateTime date) =>
      DateFormat('d MMM y, HH.mm', _locale).format(date.toLocal());

  /// Short weekday, e.g. "Sen".
  static String weekdayShort(DateTime date) =>
      DateFormat('E', _locale).format(date.toLocal());

  /// Long weekday, e.g. "Senin".
  static String weekdayLong(DateTime date) =>
      DateFormat('EEEE', _locale).format(date.toLocal());

  /// `yyyy-MM-dd`, for API query parameters.
  static String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Strips the time component.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
