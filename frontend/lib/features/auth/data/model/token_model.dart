import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_model.freezed.dart';
part 'token_model.g.dart';

/// Data model for the token pair returned by POST /auth/refresh.
///
/// Declared with [@freezed] and [@JsonSerializable] to generate both
/// immutability helpers and JSON serialisation.  This model is used
/// exclusively in the data layer; it is not exposed to the domain.
@freezed
abstract class TokenModel with _$TokenModel {
  const factory TokenModel({
    /// JWT access token (short-lived).
    @JsonKey(name: 'access_token') required String accessToken,

    /// Opaque refresh token (long-lived, rotated on ech use).
    @JsonKey(name: 'refresh_token') required String refreshToken,
  }) = _TokenModel;

  factory TokenModel.fromJson(Map<String, dynamic> json) =>
      _$TokenModelFromJson(json);
}
