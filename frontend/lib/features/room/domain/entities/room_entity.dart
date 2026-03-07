import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_entity.freezed.dart';

/// Domain entity representing a public or private viewing room.
///
/// Declared with [@freezed] for structural equality, immutability and
/// `copyWith` support, consistent with all other domain entities in this
/// project ([UserEntity], [Failure], etc.).
///
/// This is the MVP shape required by [HomePage] to display the public room
/// listing. The `memberCount` and `videoUrl` fields will be added to this
/// entity once the Room feature is developed.
@freezed
abstract class RoomEntity with _$RoomEntity {
  const factory RoomEntity({
    /// Unique room identifier (UUID v4).
    required String id,

    /// Display name shown on the room display.
    required String name,

    /// Whether the room requires an invitation link to join.
    required bool isPrivate,
  }) = _RoomEntity;
}