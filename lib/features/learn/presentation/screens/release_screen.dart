import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/security/secure_screen.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/core/widgets/soft_blobs.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/session_done_view.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Lepaskan pikiran": write one worry, then let it float away.
///
/// The text exists only in the text field while typing and in the
/// animation; it is never stored, logged, or sent, and it is cleared from
/// memory as soon as the animation ends. Screenshots are blocked.
class ReleaseScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends ConsumerState<ReleaseScreen>
    with SingleTickerProviderStateMixin {
  static const _floatDuration = Duration(milliseconds: 1500);

  final _text = TextEditingController();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: _floatDuration,
  );

  /// Copy shown only while floating away; null otherwise.
  String? _floating;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _float.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void dispose() {
    _text
      ..clear()
      ..dispose();
    _float.dispose();
    super.dispose();
  }

  void _release() {
    final value = _text.text.trim();
    if (value.isEmpty || _floating != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _floating = value);
    _text.clear();
    _float.forward(from: 0);
  }

  void _finish() {
    setState(() {
      _floating = null;
      _done = true;
    });
    unawaited(
      ref
          .read(gardenControllerProvider.notifier)
          .recordSession(LearnKind.release),
    );
  }

  void _again() => setState(() => _done = false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.exerciseReleaseTitle)),
        body: SafeArea(
          top: false,
          child: _done
              ? SessionDoneView(
                  title: l10n.releaseDone,
                  repeatLabel: l10n.releaseAgain,
                  onRepeat: _again,
                )
              : _writing(l10n),
        ),
      ),
    );
  }

  Widget _writing(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final floating = _floating;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) _release();
      },
      child: Stack(
        children: [
          const Positioned.fill(child: SoftBlobs()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Text(l10n.releasePrompt, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.releasePrivacy, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              if (floating == null)
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                )
              else
                AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      reduceMotion ? 0 : -AppSizes.breathingMax * _float.value,
                    ),
                    child: Opacity(opacity: 1 - _float.value, child: child),
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(floating, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.releaseSwipeHint,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.releaseButton,
                icon: Icons.cloud_outlined,
                onPressed: _text.text.trim().isEmpty || floating != null
                    ? null
                    : _release,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
