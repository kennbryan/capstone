import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Avatar initial, display name (editable), and email.
class ProfileHeader extends ConsumerWidget {
  const new({super.key});

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: current),
    );
    if (name == null || !context.mounted) return;
    final failure = await ref
        .read(authControllerProvider.notifier)
        .updateDisplayName(name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null ? l10n.profileNameSaved : l10n.describeError(failure),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final onBrand = context.gradients.onBrand;
    return HeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs / 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: onBrand.withValues(alpha: 0.6),
                width: AppSizes.borderStrong,
              ),
            ),
            child: CircleAvatar(
              radius: AppSizes.avatarLg / 2,
              backgroundColor: onBrand,
              child: Text(
                user.initial,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(color: onBrand),
                ),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onBrand.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.profileEditName,
            color: onBrand,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editName(context, ref, user.displayName),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  static const _nameMaxLength = 40;

  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.profileEditName),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: _nameMaxLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.profileNameLabel),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? l10n.profileNameRequired : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// Version, AI disclaimer, and credits.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MsuLogo(size: AppSizes.logoSm),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          return Text(
                            info == null
                                ? l10n.aboutVersion('–')
                                : l10n.aboutVersionBuild(
                                    info.version,
                                    info.buildNumber,
                                  ),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.brandSubtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.aboutDisclaimer, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.aboutDataTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.aboutData, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.aboutCredits, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.aboutFont, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.aboutSounds, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.aboutLicenses),
              onPressed: () async {
                final info = await PackageInfo.fromPlatform();
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: info.version,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
