import 'package:freezed_annotation/freezed_annotation.dart';
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
        SourceRefDto(articleId: source.articleId, title: source.title),
    ],
    suggestions: [
      for (final ref in message.suggestions)
        LearnRefDto(kind: ref.kind.name, id: ref.id, title: ref.title),
    ],
  );
}

@freezed
abstract class SourceRefDto with _$SourceRefDto {
  const factory({required String articleId, required String title}) =
      _SourceRefDto;

  factory fromJson(Map<String, Object?> json) => _$SourceRefDtoFromJson(json);
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
        SourceRef(articleId: source.articleId, title: source.title),
    ],
    suggestions: [
      for (final ref in suggestions)
        LearnRef(
          kind: _byName(LearnKind.values, ref.kind, LearnKind.article),
          id: ref.id,
          title: ref.title,
        ),
    ],
  );
}
