import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/features/chat/domain/whatsapp_link.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Shows the "leaving the app" notice, then opens WhatsApp with a generic
/// message only. Shows a snackbar if WhatsApp cannot be opened.
Future<void> openPsychologistWhatsApp(
  BuildContext context,
  WidgetRef ref,
  String number,
) async {
  final l10n = context.l10n;
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _WhatsAppNotice(),
  );
  if (proceed != true || !context.mounted) return;

  final uri = WhatsAppLink.build(number: number, message: l10n.whatsappPrefill);
  final opened = uri != null && await ref.read(linkLauncherProvider).open(uri);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.whatsappFailed)));
  }
}

/// "Chat via WhatsApp" button, or an unavailable message when remote
/// config has no number.
class WhatsAppButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final number = ref.watch(
      remoteConfigProvider.select((c) => c.value?.whatsappNumber),
    );
    if (number == null || number.isEmpty) {
      return Column(
        children: [
          const Illustration(
            IllustrationKind.away,
            height: AppSizes.illustrationSm,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.psychologistUnavailable,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => openPsychologistWhatsApp(context, ref, number),
        icon: const Icon(Icons.chat_outlined),
        label: Text(l10n.psychologistWhatsApp),
      ),
    );
  }
}

class _WhatsAppNotice extends StatelessWidget {
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.whatsappNoticeTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.whatsappNotice, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.whatsappContinue),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
