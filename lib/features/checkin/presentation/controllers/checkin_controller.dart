import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/checkin/data/checkin_repository_impl.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkin_controller.freezed.dart';
part 'checkin_controller.g.dart';

/// Today's check-in plus the last seven days (oldest first).
@freezed
abstract class CheckInWeek with _$CheckInWeek {
  const factory({required List<CheckInDay> days}) = _CheckInWeek;
  const new _();

  CheckIn? get today => days.last.checkIn;
}

@riverpod
class CheckInController extends _$CheckInController {
  /// Clock for "today"; tests can replace it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @override
  Future<CheckInWeek> build() async {
    ref.watch(currentUserIdProvider);
    final today = DateFormatter.dateOnly(now());
    final from = today.subtract(
      const Duration(days: CheckInRules.weekDays - 1),
    );
    final result = await ref
        .watch(checkInRepositoryProvider)
        .getCheckIns(from: from, to: today);
    return _week(from, result.unwrap());
  }

  /// Saves today's mood. Returns the failure, or null on success.
  Future<ApiException?> save({required int mood, String? note}) async {
    final today = DateFormatter.dateOnly(now());
    final result = await ref
        .read(checkInRepositoryProvider)
        .save(date: today, mood: mood, note: note);
    return result.fold<ApiException?>(
      onSuccess: (saved) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              days: [
                for (final day in current.days)
                  if (DateFormatter.isSameDay(day.date, today))
                    day.copyWith(checkIn: saved)
                  else
                    day,
              ],
            ),
          );
        }
        return null;
      },
      onFailure: (error) => error,
    );
  }

  static CheckInWeek _week(DateTime from, List<CheckIn> checkIns) {
    return CheckInWeek(
      days: [
        for (var i = 0; i < CheckInRules.weekDays; i++)
          CheckInDay(
            date: from.add(Duration(days: i)),
            checkIn: checkIns
                .where(
                  (c) => DateFormatter.isSameDay(
                    c.date,
                    from.add(Duration(days: i)),
                  ),
                )
                .firstOrNull,
          ),
      ],
    );
  }
}
