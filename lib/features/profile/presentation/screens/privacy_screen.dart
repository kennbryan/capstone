import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Privasi & izin": the required scope (explained, not toggleable) and
/// the optional personalization scope. Each change adds a consent record.
class PrivacyScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _setPersonalize(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = context.l10n;
    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.privacyWithdrawTitle),
          content: Text(l10n.privacyWithdrawBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.privacyWithdrawConfirm),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
    }
    final failure = await ref.read(consentControllerProvider.notifier).grant({
      ConsentScope.processData,
      if (enabled) ConsentScope.personalizeWithReport,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null ? l10n.privacyUpdated : l10n.describeError(failure),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(currentConsentProvider);
    final personalize =
        current?.grantedScopes.contains(ConsentScope.personalizeWithReport) ??
        false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profilePrivacy)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.privacyRequiredTitle),
              subtitle: Text(l10n.privacyRequiredBody),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: const Icon(Icons.tune),
              title: Text(l10n.privacyOptionalTitle),
              subtitle: Text(l10n.privacyOptionalBody),
              value: personalize,
              onChanged: current == null
                  ? null
                  : (value) => _setPersonalize(context, ref, enabled: value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.consentHistory),
            icon: const Icon(Icons.history),
            label: Text(l10n.profileConsentHistory),
          ),
        ],
      ),
    );
  }
}
