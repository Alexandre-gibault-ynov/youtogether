import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/auth/data/models/user_model.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';

import '../../../../common/fixtures/fixture_reader.dart';

/// Contract tests for [UserModel].
///
/// Verifies that the Dart model layer correctly deserializes every JSON shape
/// that the NestJS backend can return.
///
/// Rationale: contract tests form the first line of defence against
/// breaking API changes. They run in milliseconds without any network access,
/// using captured fixture files as ground truth. A field rename or type change
/// in the backend response immediately breaks the corresponding assertion here.
///
/// Fixtures are located in `test/features/auth/fixtures/` and are captured
/// from real backend responses via the Postman collection.
void main() {
  group('UserModel.fromJson — contract tests', () {
    // ── Session response (register / login / refresh) ─────────────────────

    group('session response (access_token + refresh_token present)', () {
      late Map<String, dynamic> json;
      late UserModel model;

      setUpAll(() {
        json = FixtureDirectory.auth.read('auth_session_success.json');
        model = UserModel.fromJson(json);
      });

      test('parses id as UUID string', () {
        expect(model.id, equals('3fa85f64-5717-4562-b3fc-2c963f66afa6'));
      });

      test('parses email', () {
        expect(model.email, equals('alice@example.com'));
      });

      test('parses username into displayName', () {
        // JSON key is "username"; Dart field is "displayName" via @JsonKey.
        expect(model.displayName, equals('Alice'));
      });

      test('parses role as string', () {
        expect(model.role, equals('registered'));
      });

      test('parses created_at as DateTime', () {
        expect(model.createdAt, isA<DateTime>());
        expect(model.createdAt.year, equals(2026));
      });

      test('parses access_token as non-empty string', () {
        expect(model.accessToken, isNotNull);
        expect(model.accessToken, isNotEmpty);
      });

      test('parses refresh_token as non-empty string', () {
        expect(model.refreshToken, isNotNull);
        expect(model.refreshToken, isNotEmpty);
      });

      test('access_token and refresh_token are distinct', () {
        expect(model.accessToken, isNot(equals(model.refreshToken)));
      });
    });

    // ── /auth/me response (no tokens) ─────────────────────────────────────

    group('/auth/me response (no tokens)', () {
      late Map<String, dynamic> json;
      late UserModel model;

      setUpAll(() {
        json = FixtureDirectory.auth.read('auth_me_success.json');
        model = UserModel.fromJson(json);
      });

      test('parses id', () {
        expect(model.id, equals('3fa85f64-5717-4562-b3fc-2c963f66afa6'));
      });

      test('access_token is null when absent from JSON', () {
        expect(model.accessToken, isNull);
      });

      test('refresh_token is null when absent from JSON', () {
        expect(model.refreshToken, isNull);
      });
    });

    // ── toDomain() mapping ────────────────────────────────────────────────

    group('toDomain()', () {
      test('maps role "registered" → UserRole.authenticated', () {
        final model = UserModel.fromJson(
          FixtureDirectory.auth.read('auth_session_success.json'),
        );
        final entity = model.toDomain();
        expect(entity.role, equals(UserRole.authenticated));
      });

      test('maps all scalar fields without loss', () {
        final model = UserModel.fromJson(
          FixtureDirectory.auth.read('auth_session_success.json'),
        );
        final entity = model.toDomain();

        expect(entity.id, equals(model.id));
        expect(entity.email, equals(model.email));
        expect(entity.displayName, equals(model.displayName));
        expect(entity.createdAt, equals(model.createdAt));
      });

      test('does NOT expose access_token or refresh_token in domain entity', () {
        final model = UserModel.fromJson(
          FixtureDirectory.auth.read('auth_session_success.json'),
        );
        final entity = model.toDomain();

        // @freezed generates toString() with all field values.
        // If a token field leaked into the entity, it would appear here.
        final entityString = entity.toString();
        expect(entityString, isNot(contains(model.accessToken!)));
        expect(entityString, isNot(contains(model.refreshToken!)));
      });
    });
  });

  // ── ErrorResponseBody shape ───────────────────────────────────────────────

  group('ErrorResponseBody fixtures — shape assertions', () {
    test('409 Conflict fixture has correct structure', () {
      final json = FixtureDirectory.auth.read('error_conflict_409.json');

      expect(json['statusCode'], equals(409));
      expect(json['error'], equals('Conflict'));
      expect(json['message'], isA<String>());
      expect(json['errors'], isNull);
      expect(json['timestamp'], isA<String>());
      expect(json['path'], isA<String>());
    });

    test('401 Unauthorized fixture has correct structure', () {
      final json = FixtureDirectory.auth.read('error_unauthorized_401.json');

      expect(json['statusCode'], equals(401));
      expect(json['error'], equals('Unauthorized'));
      expect(json['errors'], isNull);
    });

    test('403 Forbidden fixture has correct structure', () {
      final json = FixtureDirectory.auth.read('error_forbidden_403.json');

      expect(json['statusCode'], equals(403));
      expect(json['error'], equals('Forbidden'));
    });

    test('422 Validation fixture contains field-keyed errors map', () {
      final json = FixtureDirectory.auth.read('error_validation_422.json');

      expect(json['statusCode'], equals(422));
      expect(json['errors'], isA<Map<String, dynamic>>());

      final errors = json['errors'] as Map<String, dynamic>;
      expect(errors.containsKey('email'), isTrue);
      expect(errors.containsKey('password'), isTrue);
      expect(errors['email'], isA<String>());
      expect(errors['password'], isA<String>());
    });

    test('422 errors values are non-empty strings', () {
      final json = FixtureDirectory.auth.read('error_validation_422.json');
      final errors = json['errors'] as Map<String, dynamic>;

      for (final entry in errors.entries) {
        expect(
          entry.value,
          isA<String>(),
          reason: 'errors["${entry.key}"] must be a String',
        );
        expect(
          (entry.value as String).isNotEmpty,
          isTrue,
          reason: 'errors["${entry.key}"] must not be empty',
        );
      }
    });
  });
}