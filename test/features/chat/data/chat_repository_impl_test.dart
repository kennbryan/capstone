import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/chat/data/chat_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/data/sources/chat_sources.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/in_memory_secure_storage.dart';

void main() {
  late InMemorySecureStorage storage;
  late ChatRepositoryImpl repo;

  setUp(() {
    ChatMockSource.reset();
    storage = InMemorySecureStorage();
    repo = ChatRepositoryImpl(
      ChatMockSource(const MockSettings(instant: true), Random(1)),
      ChatHistoryStore(storage),
    );
  });

  test('rotates plain, sources, and suggestions replies', () async {
    final first = (await repo.send('a')).unwrap();
    final second = (await repo.send('b')).unwrap();
    final third = (await repo.send('c')).unwrap();

    expect(first.role, MessageRole.assistant);
    expect(first.sources, isEmpty);
    expect(first.suggestions, isEmpty);
    expect(second.sources.single.articleId, 'art_01');
    expect(third.suggestions.single.kind, LearnKind.breathing);
  });

  test('#tes-krisis returns a crisis reply', () async {
    final reply = (await repo.send('tolong #tes-krisis')).unwrap();
    expect(reply.type, MessageType.crisis);
  });

  test('history is saved per user and can be cleared', () async {
    final message = ChatMessage(
      id: 'm1',
      role: MessageRole.user,
      text: 'halo',
      createdAt: DateTime.utc(2026),
    );
    await repo.saveHistory('usr_a', [message]);

    expect(await repo.loadHistory('usr_a'), [
      message.copyWith(createdAt: message.createdAt.toLocal()),
    ]);
    expect(await repo.loadHistory('usr_b'), isEmpty);
    expect(storage.values.keys, [SecureKeys.chatHistory('usr_a')]);

    await repo.clearHistory('usr_a');
    expect(await repo.loadHistory('usr_a'), isEmpty);
  });
}
