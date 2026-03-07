import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:youtogether/core/router/app_routes.dart';
import 'package:youtogether/features/auth/presentation/pages/login_page.dart';
import 'package:youtogether/features/auth/presentation/pages/register_page.dart';
import 'package:youtogether/features/room/presentation/pages/home_page.dart';
import 'package:youtogether/main.dart' as app;

// ---------------------------------------------------------------------------
// Prerequisites
// ---------------------------------------------------------------------------
//
// These tests require a running NestJS backend accessible from the test device:
//
//   Android emulator : http://10.0.2.2:3000/api  (default)
//   iOS Simulator    : http://127.0.0.1:3000/api
//   Physical device  : http://<host-machine-LAN-IP>:3000/api
//
// Start the backend before running:
//   cd youtogether_backend && npm run start:dev
//
// Run the integration tests:
//   flutter test integration_test/auth_e2e_test.dart \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
//
// Architecture notes:
//
// 1. SINGLE testWidgets BLOCK — All E2E scenarios are executed inside a single
//    [testWidgets] call. This is the required pattern when tests share live app
//    state across scenarios.
//
//    [IntegrationTestWidgetsFlutterBinding] calls _cleanUpTest() between each
//    [testWidgets] invocation, which issues runApp(Container()) and tears down
//    the entire widget tree. Using one block avoids this teardown entirely.
//
// 2. STARTUP — [app.initApp] is called via [tester.runAsync] so that
//    platform-channel operations (flutter_secure_storage, Dio) complete before
//    the first frame is pumped. [waitFor] then polls until [HomePage] appears,
//    absorbing the [AuthBloc.checkStatusRequested] async round trip.
//
// 3. NAVIGATION — The app uses GoRouter ([MaterialApp.router]).
//    [GoRouter.of(context)] requires a context from inside the router subtree.
//    [find.byType(Scaffold).first] provides such a context because every page
//    built by GoRouter contains a Scaffold.
//
// 4. PUMP STRATEGY — [waitFor] chains [tester.pump(200ms)] calls until a
//    Finder matches. This is correct for operations backed by real network or
//    platform channels whose duration is non-deterministic.
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Unique email — avoids HTTP 409 Conflict on repeated runs without
  // resetting the database.
  final testEmail =
      'e2e_${DateTime.now().millisecondsSinceEpoch}@youtogether.test';
  const testPassword = 'E2eP@ssword1234';
  const testUsername = 'E2EUser';

  // ---------------------------------------------------------------------------
  // All E2E scenarios in a single testWidgets block.
  //
  // The block name follows the test catalogue: each scenario is
  // clearly delimited by a step comment that matches the test case ID in the
  // recette document.
  // ---------------------------------------------------------------------------

  testWidgets('YouTogether — Auth E2E suite', (tester) async {
    // ── Helpers ────────────────────────────────────────────────────────────────

    /// Pumps at 200 ms intervals until [finder] matches at least one widget.
    ///
    /// Preferred over [tester.pumpAndSettle] whenever the operation involves a
    /// platform channel or a real network call whose duration is unknown.
    Future<void> waitFor(
        Finder finder, {
          Duration timeout = const Duration(seconds: 15),
        }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (finder.evaluate().isNotEmpty) return;
      }
      throw StateError(
        'Widget not found after ${timeout.inSeconds}s: $finder',
      );
    }

    /// Navigates to [AppRoutes.homePage] and waits for [HomePage] to appear.
    ///
    /// [GoRouter.of()] requires a [BuildContext] from inside the router subtree.
    /// [find.byType(Scaffold).first] satisfies this because every GoRouter page
    /// contains a Scaffold at its root.
    Future<void> goHome() async {
      await waitFor(find.byType(Scaffold));
      final element = tester.element(find.byType(Scaffold).first);
      GoRouter.of(element).go(AppRoutes.homePage);
      await waitFor(find.byType(HomePage));
      // Drain all pending animations so that the previous route is fully
      // unmounted before the next interaction. Without this, GoRouter keeps
      // both pages in the widget tree during the exit transition, causing key
      // collisions when the test taps a widget that exists on both pages.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    // ── App startup ────────────────────────────────────────────────────────────

    // [tester.runAsync] runs [initApp] in a zone where platform-channel calls
    // are allowed. [runApp] is called inside [initApp]; subsequent [pump] calls
    // render the first frames.
    await tester.runAsync(app.initApp);
    await waitFor(find.byType(HomePage));

    // =========================================================================
    // TC-E2E-01 — App cold-start displays HomePage
    // =========================================================================

    expect(
      find.byType(HomePage),
      findsOneWidget,
      reason: 'Initial route must be HomePage (unauthenticated state).',
    );
    expect(find.text('YouTogether'), findsWidgets);
    expect(
      find.byKey(const Key('home_login_button')),
      findsOneWidget,
      reason: 'Unauthenticated state must expose the Connexion action.',
    );

    // =========================================================================
    // TC-E2E-02 — Navigate to LoginPage
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(LoginPage), findsOneWidget);

    // =========================================================================
    // TC-E2E-03 — Navigate from LoginPage to RegisterPage
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('login_create_account_button')));
    await waitFor(find.byType(RegisterPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text('Création de compte'), findsOneWidget);

    // =========================================================================
    // TC-E2E-04 — Client-side validation on empty RegisterPage form
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('login_create_account_button')));
    await waitFor(find.byType(RegisterPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pump();

    expect(find.text("L'adresse email est requise."), findsOneWidget);
    // RegisterPage must remain — no navigation on client-side validation failure.
    expect(find.byType(RegisterPage), findsOneWidget);

    // =========================================================================
    // TC-E2E-05 — Full registration flow (real backend)
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('login_create_account_button')));
    await waitFor(find.byType(RegisterPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // field index 0 — email
    await tester.enterText(find.byType(TextFormField).at(0), testEmail);
    // field index 1 — username
    await tester.enterText(find.byType(TextFormField).at(1), testUsername);
    // field index 2 — password
    await tester.enterText(find.byType(TextFormField).at(2), testPassword);
    // field index 3 — confirm password
    await tester.enterText(find.byType(TextFormField).at(3), testPassword);

    await tester.tap(find.byKey(const Key('register_submit_button')));

    // Wait for the backend call and for RegisterPage to pop back to LoginPage.
    await waitFor(
      find.byType(LoginPage),
      timeout: const Duration(seconds: 20),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);

    // =========================================================================
    // TC-E2E-06 — Login with wrong password shows error SnackBar
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextFormField).at(0), testEmail);
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');

    await tester.tap(find.byKey(const Key('login_submit_button')));

    // Wait for the network call to fail and for the SnackBar to appear.
    await waitFor(find.byType(SnackBar), timeout: const Duration(seconds: 20));

    expect(find.byType(SnackBar), findsOneWidget);
    // LoginPage must remain — no navigation on authentication failure.
    expect(find.byType(LoginPage), findsOneWidget);

    // =========================================================================
    // TC-E2E-08 — Cancel registration returns to LoginPage
    // =========================================================================
    // Execute TC-E2E-08 before TC-E2E-07 because the logout feature is not
    // implemented yet. So when the login flow is complete, there is no way
    // to reach the login and register screens.

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('login_create_account_button')));
    await waitFor(find.byType(RegisterPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('register_cancel_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);

    // =========================================================================
    // TC-E2E-07 — Full login flow (real backend)
    // =========================================================================

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Use the account created in TC-E2E-05 (same testEmail, same run).
    await tester.enterText(find.byType(TextFormField).at(0), testEmail);
    await tester.enterText(find.byType(TextFormField).at(1), testPassword);

    await tester.tap(find.byKey(const Key('login_submit_button')));

    // Wait for authentication and GoRouter redirect to HomePage.
    await waitFor(
      find.byType(HomePage),
      timeout: const Duration(seconds: 20),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    // After authentication the AppBar action must show 'Profil'.
    expect(find.text('Profil'), findsOneWidget);
  });
}