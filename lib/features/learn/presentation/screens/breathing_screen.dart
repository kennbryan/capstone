import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/soft_blobs.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/breathing_pattern.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/breathing_widgets.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/session_done_view.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

enum _Stage { setup, running, done }

/// "Napas tenang": guided 4 s in / 6 s out, or hold-to-breathe.
class BreathingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _hold = AnimationController(vsync: this);

  _Stage _stage = _Stage.setup;
  int _minutes = BreathingPattern.durations[1];
  bool _holdMode = false;
  Duration _elapsed = Duration.zero;
  BreathPhase _phase = BreathPhase.inhale;

  Duration get _total => Duration(minutes: _minutes);

  @override
  void initState() {
    super.initState();
    _hold.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _stage = _Stage.running;
      _elapsed = Duration.zero;
      _phase = BreathPhase.inhale;
    });
    _hold.value = 0;
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    setState(() => _stage = _Stage.setup);
  }

  void _onTick(Duration elapsed) {
    if (elapsed >= _total) {
      _ticker.stop();
      setState(() => _stage = _Stage.done);
      unawaited(
        ref
            .read(gardenControllerProvider.notifier)
            .recordSession(LearnKind.breathing),
      );
      return;
    }
    final phase = BreathingPattern.at(elapsed).phase;
    if (!_holdMode && phase != _phase) _buzz();
    setState(() {
      _elapsed = elapsed;
      _phase = phase;
    });
  }

  void _buzz() {
    if (ref.read(hapticsControllerProvider)) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _press() {
    _buzz();
    _hold.animateTo(1, duration: BreathingPattern.inhale);
  }

  void _release() {
    _buzz();
    _hold.animateTo(0, duration: BreathingPattern.exhale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exerciseBreathingTitle)),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.setup => BreathingSetup(
            minutes: _minutes,
            holdMode: _holdMode,
            onMinutes: (value) => setState(() => _minutes = value),
            onHoldMode: (value) => setState(() => _holdMode = value),
            onStart: _start,
          ),
          _Stage.running => _running(l10n),
          _Stage.done => SessionDoneView(onRepeat: _start),
        },
      ),
    );
  }

  Widget _running(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final guided = BreathingPattern.at(_elapsed);
    final inhaling = _holdMode
        ? _hold.status == AnimationStatus.forward || _hold.value == 1
        : guided.phase == BreathPhase.inhale;
    final cue = inhaling ? l10n.breathingInhale : l10n.breathingExhale;
    final label = _holdMode && _hold.value == 0 && !inhaling
        ? l10n.breathingHoldPrompt
        : cue;
    final circle = BreathingCircle(
      size: _holdMode ? _hold.value : guided.size,
      label: label,
      sessionProgress: _elapsed.inMilliseconds / _total.inMilliseconds,
    );

    return Stack(
      children: [
        const Positioned.fill(child: SoftBlobs()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: _holdMode
                      ? GestureDetector(
                          onTapDown: (_) => _press(),
                          onTapUp: (_) => _release(),
                          onTapCancel: _release,
                          child: circle,
                        )
                      : circle,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.remainingTime(
                    BreathingPattern.formatRemaining(_total - _elapsed),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: _stop,
                  child: Text(l10n.breathingStop),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
