import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Data model representing the API response for a user resource.
///
/// Annotated with [@freezed] for immutability and [@JsonSerializable] for
/// JSON deserialisation of the NestJS API response payload.
///
/// The [toDomain] extension method is the single crossing point between
/// the raw API representation and the [UserEntity] domain object.
///
/// JSON field names follow the snake_case convention used by the NestJS API.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    /// Unique user identifier (UUID v4).
    required String id,

    /// User email address.
    required String email,

    /// Display name shown in the UI.
    @JsonKey(name: 'username') required String displayName,

    /// User role as returned by the API ('registered' | 'guest').
    required String role,

    /// JWT access token embedded in the login / Google OAuth2 response.
    ///
    /// This field is nullable because GET /auth/me does not re-issue tokens.
    @JsonKey(name: 'access_token') String? accessToken,

    /// Refresh token embedded in the login / Google OAuth2 response.
    @JsonKey(name: 'refresh_token') String? refreshToken,

    /// UTC timestamp of account creation.
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

/// Extension providing domain conversion for [UserModel].
///
/// [toDomain] is the sole crossing point from the data layer into the domain.
/// It maps raw API string values to typed domain enumerations and value objects.
extension UserModelX on UserModel {
  UserEntity toDomain() => UserEntity(
    id: id,
    email: email,
    displayName: displayName,
    role: role == 'registered' ? UserRole.authenticated : UserRole.viewer,
    createdAt: createdAt,
  );
}
