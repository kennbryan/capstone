import 'dart:async';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sounds_controller.freezed.dart';
part 'sounds_controller.g.dart';

/// Royalty-free loops bundled in `assets/audio/` (see ASSETS.md).
enum SoundTrack {
  hujan('assets/audio/rain.wav'),
  hutan('assets/audio/forest.wav'),
  ombak('assets/audio/waves.wav');

  new(this.asset);

  final String asset;
}

/// Timer options, in minutes.
const soundTimerOptions = [5, 10, 15];

/// Tracks whose audio file is bundled. Missing ones show "Segera hadir".
@riverpod
Future<Set<SoundTrack>> availableSounds(Ref ref) async {
  final available = <SoundTrack>{};
  for (final track in SoundTrack.values) {
    try {
      await rootBundle.load(track.asset);
      available.add(track);
    } on Object {
      // Not bundled yet.
    }
  }
  return available;
}

@freezed
abstract class SoundsState with _$SoundsState {
  const factory({
    SoundTrack? playing,
    @Default(10) int minutes,
    @Default(Duration.zero) Duration remaining,
    @Default(false) bool paused,
  }) = _SoundsState;
}

/// Foreground playback with a timer and a 5 s fade-out. Counts toward the
/// garden after one minute of listening.
@riverpod
class SoundsController extends _$SoundsController {
  static const _fade = Duration(seconds: 5);
  static const _fadeSteps = 20;
  static const _countAfter = Duration(minutes: 1);

  AudioPlayer? _player;
  Timer? _timer;
  Duration _listened = Duration.zero;
  bool _counted = false;

  @override
  SoundsState build() {
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_player?.dispose());
    });
    return const SoundsState();
  }

  set minutes(int value) => state = state.copyWith(minutes: value);

  int get minutes => state.minutes;

  /// Starts [track]. Returns false if playback failed.
  Future<bool> play(SoundTrack track) async {
    await stop();
    try {
      final player = _player ??= AudioPlayer();
      await player.setAsset(track.asset);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1);
      unawaited(player.play());
    } on Object catch (error, stackTrace) {
      AppLogger.error('sounds.play', error, stackTrace);
      return false;
    }
    _listened = Duration.zero;
    _counted = false;
    state = state.copyWith(
      playing: track,
      paused: false,
      remaining: Duration(minutes: state.minutes),
    );
    _startTimer();
    return true;
  }

  /// Pauses playback, e.g. when the app goes to the background.
  Future<void> pause() async {
    if (state.playing == null || state.paused) return;
    _timer?.cancel();
    await _player?.pause();
    state = state.copyWith(paused: true);
  }

  Future<void> resume() async {
    if (state.playing == null || !state.paused) return;
    unawaited(_player?.play());
    state = state.copyWith(paused: false);
    _startTimer();
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _player?.stop();
    state = state.copyWith(playing: null, paused: false);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    const second = Duration(seconds: 1);
    _listened += second;
    if (!_counted && _listened >= _countAfter) {
      _counted = true;
      unawaited(
        ref
            .read(gardenControllerProvider.notifier)
            .recordSession(LearnKind.sounds),
      );
    }
    final remaining = state.remaining - second;
    state = state.copyWith(remaining: remaining);
    if (remaining <= Duration.zero) unawaited(_fadeOut());
  }

  Future<void> _fadeOut() async {
    _timer?.cancel();
    final step = _fade ~/ _fadeSteps;
    for (var i = 1; i <= _fadeSteps; i++) {
      await Future<void>.delayed(step);
      if (!ref.mounted) return;
      await _player?.setVolume(1 - i / _fadeSteps);
    }
    await stop();
  }
}
