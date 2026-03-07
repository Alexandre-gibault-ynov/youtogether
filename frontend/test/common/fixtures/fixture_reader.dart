import 'dart:convert';
import 'dart:io';

/// Enumerates the fixture directories for each application feature.
///
/// Each value encapsulates the relative path from the project root to the
/// corresponding feature's fixture directory. The [read] method centralises
/// all file-reading logic — no duplication across feature test suites.
///
/// Usage:
/// ```dart
/// final json = FixtureDirectory.auth.read('auth_session_success.json');
/// final model = UserModel.fromJson(json);
/// ```
///
/// Adding a new feature requires a single new enum value:
/// ```dart
/// room('test/features/room/fixtures'),
/// ```
enum FixtureDirectory {
  auth('test/features/auth/fixtures'),
  room('test/features/room/fixtures');

  const FixtureDirectory(this.path);

  /// Relative path from the project root to this feature's fixture directory.
  final String path;

  /// Reads [fileName] from this fixture directory and returns the decoded JSON.
  ///
  /// Throws [StateError] if the file does not exist, with a message that
  /// includes the full resolved path to aid debugging.
  Map<String, dynamic> read(String fileName) {
    final fullPath = '$path/$fileName';
    final file = File(fullPath);

    if (!file.existsSync()) {
      throw StateError(
        'Fixture file not found: $fullPath\n'
            'Ensure the file exists under $path/ and the name is correct.',
      );
    }

    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}