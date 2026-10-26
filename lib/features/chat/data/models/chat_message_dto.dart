import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_action.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';

part 'chat_message_dto.freezed.dart';
part 'chat_message_dto.g.dart';

/// `POST /chatbot/messages` response, also used for local history.
@freezed
abstract class ChatMessageDto with _$ChatMessageDto {
  const factory({
    required String id,
    required String role,
    required String text,
    required DateTime createdAt,
    @Default('normal') String type,
    @Default(<SourceRefDto>[]) List<SourceRefDto> sources,
    @Default(<LearnRefDto>[]) List<LearnRefDto> suggestions,
    @Default(<ChatActionDto>[]) List<ChatActionDto> actions,
    String? conversationId,
  }) = _ChatMessageDto;

  factory fromJson(Map<String, Object?> json) => _$ChatMessageDtoFromJson(json);

  factory fromEntity(ChatMessage message) => ChatMessageDto(
    id: message.id,
    role: message.role.name,
    text: message.text,
    createdAt: message.createdAt.toUtc(),
    type: message.type.name,
    sources: [
      for (final source in message.sources)
        SourceRefDto(
          articleId: source.articleId,
          title: source.title,
          sourceName: source.sourceName,
          url: source.url,
        ),
    ],
    suggestions: [
      for (final ref in message.suggestions)
        LearnRefDto(kind: ref.kind.name, id: ref.id, title: ref.title),
    ],
    actions: [
      for (final action in message.actions) ChatActionDto.fromEntity(action),
    ],
    conversationId: message.conversationId,
  );
}

@freezed
abstract class SourceRefDto with _$SourceRefDto {
  const factory({
    required String articleId,
    required String title,
    String? sourceName,
    String? url,
  }) = _SourceRefDto;

  factory fromJson(Map<String, Object?> json) => _$SourceRefDtoFromJson(json);
}

/// `actions[]`: `type` is snake_case (`call_phone`, `open_activity`, ...)
/// and `payload` depends on it (see `ChatRemoteSource`).
@freezed
abstract class ChatActionDto with _$ChatActionDto {
  const factory({
    required String type,
    required String label,
    @Default(<String, Object?>{}) Map<String, Object?> payload,
  }) = _ChatActionDto;

  factory fromJson(Map<String, Object?> json) => _$ChatActionDtoFromJson(json);

  factory fromEntity(ChatAction action) => ChatActionDto(
    type: _snake(action.type.name),
    label: action.label,
    payload: {
      if (action.phone != null) 'phone': action.phone,
      if (action.url != null) 'url': action.url,
      ...?action.activity?.toJson(),
    },
  );
}

String _snake(String camel) => camel.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

ActivityGuide? _activity(Map<String, Object?> payload) {
  final id = payload['id'];
  final title = payload['title'];
  final steps = payload['steps'];
  if (id is! String || title is! String || steps is! List) return null;
  return ActivityGuide(
    id: id,
    title: title,
    steps: [for (final step in steps) '$step'],
    description: payload['description'] as String? ?? '',
    durationMin: (payload['durationMin'] as num?)?.toInt(),
    sourceName: payload['sourceName'] as String?,
    sourceUrl: payload['sourceUrl'] as String?,
  );
}

extension on ActivityGuide {
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'steps': steps,
    'description': description,
    'durationMin': durationMin,
    'sourceName': sourceName,
    'sourceUrl': sourceUrl,
  };
}

extension ChatActionDtoMapper on ChatActionDto {
  ChatAction toEntity() {
    final kind = ChatActionType.values.firstWhere(
      (value) => _snake(value.name) == type,
      orElse: () => ChatActionType.unknown,
    );
    return ChatAction(
      type: kind,
      label: label,
      phone: payload['phone'] as String?,
      url: payload['url'] as String?,
      activity: kind == ChatActionType.openActivity ? _activity(payload) : null,
    );
  }
}

@freezed
abstract class LearnRefDto with _$LearnRefDto {
  const factory({required String kind, required String title, String? id}) =
      _LearnRefDto;

  factory fromJson(Map<String, Object?> json) => _$LearnRefDtoFromJson(json);
}

T _byName<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((value) => value.name == name, orElse: () => fallback);

extension ChatMessageDtoMapper on ChatMessageDto {
  ChatMessage toEntity() => ChatMessage(
    id: id,
    role: _byName(MessageRole.values, role, MessageRole.assistant),
    text: text,
    createdAt: createdAt.toLocal(),
    type: _byName(MessageType.values, type, MessageType.normal),
    sources: [
      for (final source in sources)
        SourceRef(
          articleId: source.articleId,
          title: source.title,
          sourceName: source.sourceName,
          url: source.url,
        ),
    ],
    suggestions: [
      for (final ref in suggestions)
        LearnRef(
          kind: _byName(LearnKind.values, ref.kind, LearnKind.article),
          id: ref.id,
          title: ref.title,
        ),
    ],
    actions: [
      for (final action in actions)
        if (action.toEntity() case final entity
            when entity.type != ChatActionType.unknown)
          entity,
    ],
    conversationId: conversationId,
  );
}
