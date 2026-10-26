import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/widgets/consent_widgets.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Plain-language data summary with separate required/optional toggles.
/// Shown on first run and whenever the consent version changes.
class ConsentScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _required = false;
  bool _personalize = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final previous = ref.read(currentConsentProvider);
    _personalize =
        previous?.grantedScopes.contains(ConsentScope.personalizeWithReport) ??
        false;
  }

  Future<void> _agree() async {
    setState(() => _busy = true);
    final failure = await ref.read(consentControllerProvider.notifier).grant({
      ConsentScope.processData,
      if (_personalize) ConsentScope.personalizeWithReport,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.describeError(failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hadPrevious = ref.watch(currentConsentProvider) != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consentTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.lg,
          ),
          children: [
            if (hadPrevious)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l10n.consentUpdated,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            if (hadPrevious) const SizedBox(height: AppSpacing.lg),
            Text(l10n.consentIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            ConsentSection(
              icon: Icons.folder_outlined,
              title: l10n.consentDataTitle,
              body: l10n.consentDataBody,
            ),
            ConsentSection(
              icon: Icons.flag_outlined,
              title: l10n.consentPurposeTitle,
              body: l10n.consentPurposeBody,
            ),
            ConsentSection(
              icon: Icons.lock_outline,
              title: l10n.consentTrainingTitle,
              body: l10n.consentTrainingBody,
            ),
            ConsentSection(
              icon: Icons.undo_outlined,
              title: l10n.consentWithdrawTitle,
              body: l10n.consentWithdrawBody,
            ),
            const SizedBox(height: AppSpacing.sm),
            ConsentToggle(
              label: l10n.consentRequiredLabel,
              tag: l10n.consentRequiredHint,
              value: _required,
              onChanged: _busy ? null : (v) => setState(() => _required = v),
            ),
            const SizedBox(height: AppSpacing.md),
            ConsentToggle(
              label: l10n.consentOptionalLabel,
              tag: l10n.consentOptionalHint,
              value: _personalize,
              onChanged: _busy ? null : (v) => setState(() => _personalize = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_required)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  l10n.consentRequiredMissing,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            PrimaryButton(
              label: l10n.consentAgree,
              busy: _busy,
              onPressed: _required ? _agree : null,
            ),
          ],
        ),
      ),
    );
  }
}
