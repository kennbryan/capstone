import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';
import 'package:msu_wellbeing/features/remote_config/domain/national_contacts.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Crisis contacts from remote config. Each tap opens the phone dialer.
/// If the config cannot be loaded, the verified national help lines are
/// shown instead: this list must never be empty or an error.
/// Uses crisis tokens, so it may only appear on crisis UI.
class CrisisContacts extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(remoteConfigProvider);
    if (config.isLoading && !config.hasValue) {
      return const LoadingView(compact: true);
    }
    final contacts = config.value?.crisisContacts ?? nationalCrisisContacts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final contact in contacts) ...[
          _ContactTile(contact: contact),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const new({required this.contact});

  final CrisisContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final description = contact.description;

    Future<void> call() async {
      final opened = await ref.read(linkLauncherProvider).dial(contact.phone);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
      }
    }

    return Material(
      color: colors.crisisContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: call,
        leading: Icon(Icons.call_outlined, color: colors.crisis),
        title: Text(
          contact.label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onCrisisContainer,
          ),
        ),
        subtitle: Text(
          description == null
              ? contact.phone
              : '${contact.phone} · $description',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onCrisisContainer,
          ),
        ),
        trailing: Tooltip(
          message: l10n.crisisCall(contact.label),
          child: Icon(Icons.chevron_right, color: colors.crisis),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
    );
  }
}
