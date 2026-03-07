import 'package:flutter/material.dart';

import 'app/app.dart';
import 'injection_container.dart';

/// Initialises the platform bindings, the GetIt service locator, and calls
/// [runApp].
///
/// Exposed as a named top-level function (rather than inlined in [main]) so
/// that integration tests can `await` it via [tester.runAsync] before pumping
/// the widget tree. Calling [runApp] inside [tester.runAsync] ensures that
/// the service locator is fully populated before any frame is rendered.
///
/// Execution order:
/// 1. [WidgetsFlutterBinding.ensureInitialized] — required before any async
///    platform-channel call (flutter_secure_storage, Dio).
/// 2. [initDependencies] — registers all lazily-instantiated singletons and
///    factories in the GetIt container.
/// 3. [runApp] — builds the widget tree starting at [YouTogether].
Future<void> initApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const YouTogether());
}

void main() async => initApp();