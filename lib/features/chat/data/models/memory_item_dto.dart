import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/memory_item.dart';

part 'memory_item_dto.freezed.dart';
part 'memory_item_dto.g.dart';

/// One item of `GET /chatbot/memory`.
@freezed
abstract class MemoryItemDto with _$MemoryItemDto {
  const factory({
    required String id,
    required String category,
    required String content,
    required DateTime updatedAt,
  }) = _MemoryItemDto;

  factory fromJson(Map<String, Object?> json) => _$MemoryItemDtoFromJson(json);
}

extension MemoryItemDtoMapper on MemoryItemDto {
  MemoryItem toEntity() => MemoryItem(
    id: id,
    category: category,
    content: content,
    updatedAt: updatedAt.toLocal(),
  );
}
