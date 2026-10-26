import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/chat_controller.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ChatMockSource.reset);

  test('send appends the user message and the reply, then persists', () async {
    final deps = await TestDeps.signedIn();
    final container = deps.container();
    await container.read(authControllerProvider.future);
    await container.read(chatControllerProvider.future);

    final failure = await container
        .read(chatControllerProvider.notifier)
        .send('  Halo  ');

    expect(failure, isNull);
    final state = container.read(chatControllerProvider).requireValue;
    expect(state.sending, isFalse);
    expect(state.messages.map((m) => m.role), [
      MessageRole.user,
      MessageRole.assistant,
    ]);
    expect(state.messages.first.text, 'Halo');

    await pumpEventQueue();
    expect(
      deps.secureStorage.values[SecureKeys.chatHistory('usr_test')],
      contains('Halo'),
    );
  });

  test('empty text is ignored and clearHistory wipes storage', () async {
    final deps = await TestDeps.signedIn();
    final container = deps.container();
    await container.read(authControllerProvider.future);
    await container.read(chatControllerProvider.future);
    final notifier = container.read(chatControllerProvider.notifier);

    await notifier.send('   ');
    expect(
      container.read(chatControllerProvider).requireValue.messages,
      isEmpty,
    );

    await notifier.send('Halo');
    await pumpEventQueue();
    await notifier.clearHistory();

    expect(
      container.read(chatControllerProvider).requireValue.messages,
      isEmpty,
    );
    expect(
      deps.secureStorage.values.containsKey(SecureKeys.chatHistory('usr_test')),
      isFalse,
    );
  });

  test('continues the conversation and deletes it on clear', () async {
    final deps = await TestDeps.signedIn();
    final container = deps.container();
    await container.read(authControllerProvider.future);
    await container.read(chatControllerProvider.future);
    final notifier = container.read(chatControllerProvider.notifier);

    await notifier.send('Halo');
    await notifier.send('Lanjut');
    expect(ChatMockSource.sentConversationIds, [
      null,
      ChatMockSource.conversation,
    ]);

    await notifier.clearHistory();
    expect(ChatMockSource.deletedConversations, [ChatMockSource.conversation]);
    await notifier.send('Baru lagi');
    expect(ChatMockSource.sentConversationIds.last, isNull);
  });

  test('conversation id survives a restart through local history', () async {
    final deps = await TestDeps.signedIn();
    final first = deps.container();
    await first.read(authControllerProvider.future);
    await first.read(chatControllerProvider.future);
    await first.read(chatControllerProvider.notifier).send('Halo');
    await pumpEventQueue();

    final second = deps.container();
    await second.read(authControllerProvider.future);
    final state = await second.read(chatControllerProvider.future);
    expect(state.conversationId, ChatMockSource.conversation);
  });
}
