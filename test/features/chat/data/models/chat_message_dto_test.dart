import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/chat/data/models/chat_message_dto.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_action.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';

/// A reply as the chatbot service in `chatbot/` sends it.
const Map<String, Object?> _serviceReply = {
  'id': 'msg_1',
  'role': 'assistant',
  'type': 'normal',
  'text': 'Coba tarik napas pelan dulu ya.',
  'createdAt': '2026-10-26T09:00:00.000+00:00',
  'conversationId': 'c0ffee',
  'sources': [
    {
      'articleId': 'mengelola-stres',
      'title': 'Mengelola stres',
      'sourceName': 'WHO',
      'url': 'https://www.who.int/publications/i/item/9789240003927',
    },
  ],
  'suggestions': [
    {'kind': 'breathing', 'title': 'Napas lambat 2 menit', 'id': null},
  ],
  'actions': [
    {
      'type': 'call_phone',
      'label': 'Darurat 112',
      'payload': {'phone': '112'},
    },
    {
      'type': 'open_activity',
      'label': 'Grounding',
      'payload': {
        'id': 'grounding-dwm',
        'title': 'Grounding',
        'durationMin': 3,
        'description': 'Kembali ke saat ini.',
        'steps': ['Satu', 'Dua'],
        'sourceName': 'WHO',
        'sourceUrl': 'https://www.who.int',
      },
    },
    {'type': 'something_new', 'label': 'Belum didukung'},
  ],
};

void main() {
  test('maps a chatbot service reply', () {
    final message = ChatMessageDto.fromJson(_serviceReply).toEntity();

    expect(message.conversationId, 'c0ffee');
    expect(message.sources.single.url, startsWith('https://www.who.int'));
    expect(message.sources.single.sourceName, 'WHO');
    expect(message.suggestions.single.kind, LearnKind.breathing);
    expect(message.actions.map((a) => a.type), [
      ChatActionType.callPhone,
      ChatActionType.openActivity,
    ]);
    expect(message.actions.first.phone, '112');
    final activity = message.actions.last.activity!;
    expect(activity.steps, ['Satu', 'Dua']);
    expect(activity.durationMin, 3);
  });

  test('round-trips through local history unchanged', () {
    final message = ChatMessageDto.fromJson(_serviceReply).toEntity();
    final stored = jsonDecode(
      jsonEncode(ChatMessageDto.fromEntity(message).toJson()),
    );
    final restored = ChatMessageDto.fromJson(stored as Map<String, Object?>)
        .toEntity();

    expect(restored, message);
  });

  test('an old reply without the new fields still parses', () {
    final message = ChatMessageDto.fromJson(const {
      'id': 'msg_0',
      'role': 'assistant',
      'text': 'Halo',
      'createdAt': '2026-10-22T13:00:00Z',
      'sources': [
        {'articleId': 'art_01', 'title': 'Mengelola stres akademik'},
      ],
    }).toEntity();

    expect(message.conversationId, isNull);
    expect(message.actions, isEmpty);
    expect(message.sources.single.url, isNull);
  });
}
