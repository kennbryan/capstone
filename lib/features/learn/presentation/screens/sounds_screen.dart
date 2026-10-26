import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/breathing_pattern.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/sounds_controller.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/sound_scene.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Suara tenang": three loops with a timer and a gentle fade-out.
/// Playback pauses when the app leaves the foreground.
class SoundsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () =>
          unawaited(ref.read(soundsControllerProvider.notifier).pause()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _toggle(SoundTrack track, SoundsState state) async {
    final controller = ref.read(soundsControllerProvider.notifier);
    if (state.playing == track) {
      await (state.paused ? controller.resume() : controller.stop());
      return;
    }
    final ok = await controller.play(track);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.soundsUnavailable)));
    }
  }

  String _name(AppLocalizations l10n, SoundTrack track) => switch (track) {
    SoundTrack.hujan => l10n.soundRain,
    SoundTrack.hutan => l10n.soundForest,
    SoundTrack.ombak => l10n.soundWaves,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(soundsControllerProvider);
    final available = ref.watch(availableSoundsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exerciseSoundsTitle)),
      body: switch (available) {
        AsyncData(value: final tracks) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(l10n.soundsIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.soundsTimer, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final value in soundTimerOptions)
                  ButtonSegment(value: value, label: Text(l10n.minutes(value))),
              ],
              selected: {state.minutes},
              onSelectionChanged: state.playing == null
                  ? (selection) =>
                        ref.read(soundsControllerProvider.notifier).minutes =
                            selection.first
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final track in SoundTrack.values) ...[
              _TrackCard(
                name: _name(l10n, track),
                track: track,
                enabled: tracks.contains(track),
                playing: state.playing == track,
                paused: state.paused,
                remaining: state.playing == track ? state.remaining : null,
                onTap: () => _toggle(track, state),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _TrackCard extends StatelessWidget {
  const new({
    required this.name,
    required this.track,
    required this.enabled,
    required this.playing,
    required this.paused,
    required this.remaining,
    required this.onTap,
  });

  final String name;
  final SoundTrack track;
  final bool enabled;
  final bool playing;
  final bool paused;
  final Duration? remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = remaining;
    final subtitle = !enabled
        ? l10n.comingSoon
        : time == null
        ? null
        : l10n.remainingTime(BreathingPattern.formatRemaining(time));
    final active = playing && !paused;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Semantics(
        button: enabled,
        enabled: enabled,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: enabled ? onTap : null,
          child: Row(
            children: [
              SoundScene(track: track, playing: active),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (enabled)
                Tooltip(
                  message: active ? l10n.soundsStop : l10n.soundsPlay(name),
                  child: Icon(
                    active
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    size: AppSizes.iconLg,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
