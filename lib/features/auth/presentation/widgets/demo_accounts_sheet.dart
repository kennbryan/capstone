import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Masuk dengan akun demo": lists the five demo accounts and fills the
/// form with the one picked. Shown only when `DEMO_LOGIN` is on.
class DemoAccountsButton extends ConsumerWidget {
  const new({required this.onPick, super.key});

  /// Called with the chosen account.
  final ValueChanged<DemoAccount> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compile-time guard, so builds with DEMO_LOGIN=false drop this.
    if (!AppConfig.demoLoginEnabled) return const SizedBox.shrink();
    if (ref.watch(appConfigProvider).environment.isProd) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.people_outline),
      label: Text(context.l10n.loginDemo),
      onPressed: () async {
        final account = await showModalBottomSheet<DemoAccount>(
          context: context,
          isScrollControlled: true,
          builder: (context) => const _DemoSheet(),
        );
        if (account != null) onPick(account);
      },
    );
  }
}

class _DemoSheet extends StatelessWidget {
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
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.loginDemoTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.loginDemoBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final account in demoAccounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(account.displayName.characters.first),
                ),
                title: Text(account.displayName),
                subtitle: Text('${account.email} · ${account.persona}'),
                onTap: () => Navigator.of(context).pop(account),
              ),
          ],
        ),
      ),
    );
  }
}
