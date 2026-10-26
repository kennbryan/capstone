import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/security/secure_screen.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/tab_scaffold.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/chat_controller.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/assistant_chat_view.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/psychologist_view.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

enum ChatTab {
  ai,
  psikolog;

  /// Parses the `?tab=` query value, defaulting to the assistant.
  static ChatTab parse(String? raw) =>
      raw == ChatTab.psikolog.name ? ChatTab.psikolog : ChatTab.ai;
}

/// Chat tab: "Asisten AI | Psikolog" segments. Screenshots are blocked
/// while visible.
class ChatScreen extends ConsumerStatefulWidget {
  const new({this.initialTab = ChatTab.ai, super.key});

  final ChatTab initialTab;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late ChatTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `context.go('/chat?tab=...')` from elsewhere selects the segment.
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatClearConfirmTitle),
        content: Text(l10n.chatClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chatClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(chatControllerProvider.notifier).clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SecureScreen(
      child: TabScaffold(
        title: l10n.navChat,
        actions: [
          if (_tab == ChatTab.ai)
            PopupMenuButton<void>(
              tooltip: l10n.chatMenu,
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: _confirmClear,
                  child: Text(l10n.chatClearHistory),
                ),
              ],
            ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ChatTab>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ChatTab.ai,
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: Text(l10n.chatSegmentAssistant),
                    ),
                    ButtonSegment(
                      value: ChatTab.psikolog,
                      icon: const Icon(Icons.person_outline),
                      label: Text(l10n.chatSegmentPsychologist),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) =>
                      setState(() => _tab = selection.first),
                ),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                ChatTab.ai => const AssistantChatView(),
                ChatTab.psikolog => const PsychologistView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
