import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_item.freezed.dart';

/// Something the assistant remembers about the user to personalize
/// replies, e.g. a preference or what has helped before.
@freezed
abstract class MemoryItem with _$MemoryItem {
  const factory({
    required String id,
    required String category,
    required String content,
    required DateTime updatedAt,
  }) = _MemoryItem;
}
