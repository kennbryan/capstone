import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';
import 'package:msu_wellbeing/features/checkin/presentation/widgets/check_in_note_sheet.dart';
import 'package:msu_wellbeing/features/checkin/presentation/widgets/mood_face.dart';
import 'package:msu_wellbeing/features/checkin/presentation/widgets/mood_style.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// One-tap mood check-in on the hero card. Tapping a face saves right
/// away; a note is optional and added from a small sheet.
class HeroCheckIn extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HeroCheckIn> createState() => _HeroCheckInState();
}

class _HeroCheckInState extends ConsumerState<HeroCheckIn> {
  bool _editing = false;
  int? _saving;

  Future<void> _save(int mood, {String? note}) async {
    setState(() => _saving = mood);
    final failure = await ref
        .read(checkInControllerProvider.notifier)
        .save(mood: mood, note: note);
    if (!mounted) return;
    setState(() {
      _saving = null;
      if (failure == null) _editing = false;
    });
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.describeError(failure))),
      );
    }
  }

  Future<void> _editNote(CheckIn today) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CheckInNoteSheet(initial: today.note ?? ''),
    );
    if (note != null) await _save(today.mood, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(checkInControllerProvider);
    final today = week.value?.today;
    if (week.isLoading && !week.hasValue) return const SizedBox.shrink();
    if (today != null && !_editing) {
      return _SavedState(
        today: today,
        onChange: () => setState(() => _editing = true),
        onNote: () => _editNote(today),
      );
    }
    return _Faces(selected: today?.mood, saving: _saving, onTap: _save);
  }
}

class _Faces extends StatelessWidget {
  const new({
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final int? selected;
  final int? saving;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.checkinTitle,
          style: theme.textTheme.titleSmall?.copyWith(color: onBrand),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (
              var mood = CheckInRules.minMood;
              mood <= CheckInRules.maxMood;
              mood++
            )
              Semantics(
                button: true,
                selected: mood == selected,
                label: moodLabel(l10n, mood),
                excludeSemantics: true,
                child: Tooltip(
                  message: moodLabel(l10n, mood),
                  child: InkResponse(
                    onTap: saving == null ? () => onTap(mood) : null,
                    radius: AppSizes.minTapTarget / 2 + AppSpacing.xs,
                    child: AnimatedScale(
                      // A gentle "pop" on the tapped face.
                      scale: mood == saving && !reduceMotion ? 1.12 : 1,
                      duration: AppDurations.medium,
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: AppDurations.medium,
                        curve: AppDurations.curve,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood == selected || mood == saving
                              ? onBrand
                              : onBrand.withValues(alpha: 0.16),
                          border: Border.all(
                            color: onBrand.withValues(alpha: 0.35),
                          ),
                        ),
                        child: mood == saving
                            ? SizedBox.square(
                                dimension: AppSizes.moodFace,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppSizes.borderStrong,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : MoodFace(
                                mood: mood,
                                color: mood == selected
                                    ? theme.colorScheme.primary
                                    : onBrand,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          saving == null ? l10n.checkinTapHint : l10n.checkinSaving,
          style: theme.textTheme.bodySmall?.copyWith(
            color: onBrand.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _SavedState extends StatelessWidget {
  const new({
    required this.today,
    required this.onChange,
    required this.onNote,
  });

  final CheckIn today;
  final VoidCallback onChange;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    final buttonStyle = TextButton.styleFrom(foregroundColor: onBrand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: onBrand, shape: BoxShape.circle),
              child: MoodFace(
                mood: today.mood,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeTodayMood(moodLabel(l10n, today.mood)),
                    style: theme.textTheme.titleSmall?.copyWith(color: onBrand),
                  ),
                  Text(
                    l10n.checkinThanks,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onBrand.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton.icon(
              style: buttonStyle,
              onPressed: onChange,
              icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
              label: Text(l10n.checkinEdit),
            ),
            TextButton.icon(
              style: buttonStyle,
              onPressed: onNote,
              icon: const Icon(Icons.edit_note, size: AppSizes.iconSm),
              label: Text(
                today.note == null ? l10n.checkinAddNote : l10n.checkinEditNote,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
