import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/summary_draft.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/chat_controller.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/whatsapp_flow.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Opens the editable summary draft for the psychologist. Nothing is sent:
/// the user can copy it and paste it into WhatsApp themselves.
Future<void> showSummaryDraftSheet(
  BuildContext context,
  String? conversationId,
) {
  if (conversationId == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.summaryNoConversation)));
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Above the bottom navigation bar, not under it.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => SummaryDraftSheet(conversationId: conversationId),
  );
}

class SummaryDraftSheet extends ConsumerWidget {
  const new({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = summaryDraftProvider(conversationId);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: switch (ref.watch(provider)) {
            AsyncData(:final value) => _DraftEditor(draft: value),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(provider),
            ),
            _ => const LoadingView(),
          },
        ),
      ),
    );
  }
}

class _DraftEditor extends StatefulWidget {
  const new({required this.draft});

  final SummaryDraft draft;

  @override
  State<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<_DraftEditor> {
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isEmpty) _controller.text = _compose(context.l10n);
  }

  String _compose(AppLocalizations l10n) {
    final draft = widget.draft;
    return [
      draft.summary,
      if (draft.topics.isNotEmpty) l10n.summaryTopics(draft.topics.join(', ')),
      if (draft.tried.isNotEmpty) l10n.summaryTried(draft.tried.join(', ')),
      if (draft.hopes.isNotEmpty) l10n.summaryHopes(draft.hopes),
    ].join('\n\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.summaryCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.summaryTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.summaryIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          minLines: 6,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.summaryNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy),
          label: Text(l10n.summaryCopy),
        ),
        const SizedBox(height: AppSpacing.sm),
        const WhatsAppButton(),
      ],
    );
  }
}
