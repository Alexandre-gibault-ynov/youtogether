import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

/// Role of a user.
enum UserRole {
  authenticated,
  viewer,
}


/// Domain entity representing an authenticated user.
///
/// Declared with [@freezed] to generate [copyWith], [==], [hashCode], and
/// [toString].  No [fromJson] / [toJson] is included here; serialisation is
/// the sole responsibility of [UserModel] in the data layer.
///
/// This entity is the authoritative representation of a user within the
/// domain and must never depend on any framework or transport concern.
@freezed
abstract class UserEntity with _$UserEntity {
  const factory UserEntity({
    /// Unique user identifier (UUID v4).
    required String id,

    /// User email address, used as a login credential.
    required String email,

    /// Display name shown in the UI within rooms.
    required String displayName,

    /// Role determining the user's features accessibility.
    required  UserRole role,

    /// UTC timestamp of account creation.
    required DateTime createdAt,
  }) = _UserEntity;
}