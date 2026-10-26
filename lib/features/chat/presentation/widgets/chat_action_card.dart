import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_action.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/activity_sheet.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/summary_draft_sheet.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// A button under an assistant reply. Same card style as the learning
/// suggestions, so all follow-ups look alike.
class ChatActionCard extends ConsumerWidget {
  const new({required this.action, this.conversationId, super.key});

  final ChatAction action;

  /// Conversation the reply belongs to, needed for the summary draft.
  final String? conversationId;

  IconData get _icon => switch (action.type) {
    ChatActionType.openActivity => Icons.self_improvement,
    ChatActionType.openPsychologistChat => Icons.support_agent_outlined,
    ChatActionType.prepareSummary => Icons.edit_note,
    ChatActionType.callPhone => Icons.call_outlined,
    ChatActionType.openUrl => Icons.open_in_new,
    ChatActionType.openReport => Icons.insights_outlined,
    ChatActionType.unknown => Icons.chevron_right,
  };

  Future<void> _openExternal(BuildContext context, WidgetRef ref) async {
    final launcher = ref.read(linkLauncherProvider);
    final opened = action.type == ChatActionType.callPhone
        ? await launcher.dial(action.phone ?? '')
        : await launcher.open(Uri.tryParse(action.url ?? '') ?? Uri());
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.chatLinkFailed)));
    }
  }

  VoidCallback? _onTap(BuildContext context, WidgetRef ref) {
    final activity = action.activity;
    return switch (action.type) {
      ChatActionType.callPhone ||
      ChatActionType.openUrl => () => _openExternal(context, ref),
      ChatActionType.openPsychologistChat => () => context.go(
        AppRoutes.chatPsychologist,
      ),
      ChatActionType.openReport => () => context.go(AppRoutes.reports),
      ChatActionType.prepareSummary => () => showSummaryDraftSheet(
        context,
        conversationId,
      ),
      ChatActionType.openActivity when activity != null =>
        () => showActivitySheet(context, activity),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onTap = _onTap(context, ref);
    if (onTap == null) return const SizedBox.shrink();
    final duration = action.activity?.durationMin;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
        title: Text(action.label),
        subtitle: duration == null
            ? null
            : Text(context.l10n.activityMinutes(duration)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
