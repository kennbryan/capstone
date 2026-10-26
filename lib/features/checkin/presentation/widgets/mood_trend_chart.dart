import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:msu_wellbeing/features/checkin/presentation/widgets/mood_style.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Seven-day mood trend: a smooth line with a soft gradient area, colored
/// mood dots, and hollow markers for days without a check-in (never shown
/// as a failure). Draws in from left to right unless reduce motion is on.
class MoodTrendChart extends StatelessWidget {
  const new({required this.days, super.key});

  final List<CheckInDay> days;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gradients = context.gradients;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final description = [
      for (final day in days)
        l10n.weekDayLabel(
          DateFormatter.weekdayLong(day.date),
          day.checkIn == null
              ? l10n.weekNoEntry
              : moodLabel(l10n, day.checkIn!.mood),
        ),
    ].join(', ');

    return Semantics(
      label: '${l10n.chartLabel}. $description',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.chartHeight,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
              duration: AppDurations.chart,
              curve: AppDurations.curve,
              builder: (context, progress, _) => CustomPaint(
                painter: _TrendPainter(
                  moods: [for (final day in days) day.checkIn?.mood],
                  progress: progress,
                  line: theme.colorScheme.primary,
                  grid: theme.colorScheme.outline,
                  dotRing: theme.colorScheme.surfaceContainerLowest,
                  moodColor: gradients.mood,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: _DayLabel(
                    label: DateFormatter.weekdayShort(days[i].date),
                    today: i == days.length - 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const new({required this.label, required this.today});

  final String label;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: today ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs / 2,
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: today
                ? style?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  )
                : style,
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const new({
    required this.moods,
    required this.progress,
    required this.line,
    required this.grid,
    required this.dotRing,
    required this.moodColor,
  });

  final List<int?> moods;
  final double progress;
  final Color line;
  final Color grid;
  final Color dotRing;
  final Color Function(int mood) moodColor;

  static const double _pad = AppSizes.chartDot * 2;

  Offset _point(int index, int mood, Size size) {
    final x = size.width * (index + 0.5) / moods.length;
    final usable = size.height - _pad * 2;
    final ratio =
        (mood - CheckInRules.minMood) /
        (CheckInRules.maxMood - CheckInRules.minMood);
    return Offset(x, _pad + usable * (1 - ratio));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Soft guide lines for moods 1, 3, and 5.
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = AppSizes.border;
    for (final mood in [1, 3, 5]) {
      final y = _point(0, mood, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // Contiguous runs of check-ins become smooth segments.
    final runs = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      if (mood == null) {
        if (current.isNotEmpty) runs.add(current);
        current = [];
      } else {
        current.add(_point(i, mood, size));
      }
    }
    if (current.isNotEmpty) runs.add(current);

    final area = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.chartStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final run in runs) {
      if (run.length < 2) continue;
      final path = _smooth(run);
      final fill = Path.from(path)
        ..lineTo(run.last.dx, size.height)
        ..lineTo(run.first.dx, size.height)
        ..close();
      canvas
        ..drawPath(fill, area)
        ..drawPath(path, stroke);
    }

    // Dots: colored for check-ins, hollow for skipped days.
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      if (mood == null) {
        canvas.drawCircle(
          Offset(size.width * (i + 0.5) / moods.length, size.height - _pad),
          AppSizes.chartDot - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = grid,
        );
        continue;
      }
      final center = _point(i, mood, size);
      canvas
        ..drawCircle(center, AppSizes.chartDot + 2.5, Paint()..color = dotRing)
        ..drawCircle(
          center,
          AppSizes.chartDot,
          Paint()..color = moodColor(mood),
        );
    }
    canvas.restore();
  }

  /// Catmull-Rom spline through [points] as cubic Béziers.
  static Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.line != line ||
      !_sameMoods(oldDelegate.moods);

  bool _sameMoods(List<int?> other) {
    if (other.length != moods.length) return false;
    for (var i = 0; i < moods.length; i++) {
      if (other[i] != moods[i]) return false;
    }
    return true;
  }
}
