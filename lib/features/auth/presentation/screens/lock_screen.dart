import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/brand_background.dart';
import 'package:msu_wellbeing/core/widgets/help_button.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';
import 'package:msu_wellbeing/features/profile/presentation/controllers/settings_controllers.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// App-lock gate. Prompts once on open; "Buka kunci" retries. Crisis help
/// stays reachable while locked.
class LockScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    await ref
        .read(appLockControllerProvider.notifier)
        .unlock(reason: context.l10n.lockReason);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gradients = context.gradients;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: HelpButton(onBrand: true),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MsuLogo(onBrand: true),
                        const SizedBox(height: AppSpacing.xl),
                        Icon(
                          Icons.lock_outline,
                          color: gradients.onBrand,
                          size: AppSizes.iconLg,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.lockTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: gradients.onBrand,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.lockBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: gradients.onBrand.withValues(alpha: 0.85),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: gradients.onBrand,
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: _busy ? null : _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(l10n.lockUnlock),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
