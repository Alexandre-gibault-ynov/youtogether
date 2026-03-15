import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:youtogether/core/router/app_routes.dart';
import 'package:youtogether/features/auth/presentation/pages/login_page.dart';
import 'package:youtogether/features/auth/presentation/pages/profile_page.dart';
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
//
// 5. SCENARIO ORDER — Scenarios that require an unauthenticated state
//    (TC-E2E-08, TC-E2E-06) execute before TC-E2E-05 (full registration).
//    TC-E2E-05 now ends with an auto-login; the user lands on an authenticated
//    HomePage via [AuthEvent.userSessionEstablished]. TC-E2E-09 and TC-E2E-10
//    follow directly. TC-E2E-07 (explicit login) executes last, after the
//    logout produced by TC-E2E-10, which restores the unauthenticated state
//    required to reach [LoginPage].
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Unique email — avoids HTTP 409 Conflict on repeated runs without
  // resetting the database.
  final testEmail =
      'e2e_${DateTime.now().millisecondsSinceEpoch}@youtogether.test';
  const testPassword = 'E2eP@ssword1234';
  const testUsername = 'E2EUser';

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
    Future<void> goHome() async {
      await waitFor(find.byType(Scaffold));
      final element = tester.element(find.byType(Scaffold).first);
      GoRouter.of(element).go(AppRoutes.homePage);
      await waitFor(find.byType(HomePage));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    // ── App startup ────────────────────────────────────────────────────────────

    await tester.runAsync(app.initApp);
    await waitFor(find.byType(HomePage));

    // =========================================================================
    // TC-E2E-01 — App cold-start displays unauthenticated HomePage
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
    expect(
      find.byKey(const Key('home_create_private_button')),
      findsNothing,
      reason:
      'The create-private-group action must be hidden when unauthenticated.',
    );
    expect(find.byKey(const Key('home_join_private_button')), findsOneWidget);

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
    expect(find.byType(RegisterPage), findsOneWidget);

    // =========================================================================
    // TC-E2E-08 — Cancel registration returns to LoginPage
    // =========================================================================
    // Executed before TC-E2E-05 and TC-E2E-06 because these scenarios require
    // an unauthenticated state. TC-E2E-05 now ends with an auto-login, so any
    // scenario that requires reaching [LoginPage] or [RegisterPage] directly
    // must run before it.

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
    // TC-E2E-06 — Login with wrong password shows error SnackBar
    // =========================================================================
    // Executed before TC-E2E-05 so the user is still unauthenticated and
    // [LoginPage] is reachable via the Connexion button.

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextFormField).at(0), testEmail);
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');

    await tester.tap(find.byKey(const Key('login_submit_button')));

    await waitFor(find.byType(SnackBar), timeout: const Duration(seconds: 20));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);

    // =========================================================================
    // TC-E2E-05 — Full registration flow with auto-login (real backend)
    // =========================================================================
    //
    // After a successful registration, [RegisterCubit] emits
    // [RegisterState.success(user)] with the [UserEntity] returned by the
    // backend. [RegisterPage] dispatches [AuthEvent.userSessionEstablished]
    // to [AuthBloc], which immediately emits [AuthState.authenticated].
    // [GoRouter.refreshListenable] picks up the state change and redirects
    // to [AppRoutes.homePage] — no manual navigation call is needed.
    //
    // Expected outcome:
    //   - [HomePage] is displayed (not [LoginPage]).
    //   - AppBar action shows "Profil" (authenticated state).
    //   - "Créer un groupe privé" button is visible.

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

    // Wait for the backend call, auto-login dispatch, and GoRouter redirect.
    await waitFor(
      find.byType(HomePage),
      timeout: const Duration(seconds: 20),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Registration auto-login: must land on HomePage, not LoginPage.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(LoginPage), findsNothing);

    // Session must be active immediately after registration.
    expect(
      find.byKey(const Key('home_profile_button')),
      findsOneWidget,
      reason:
      'Auto-login must establish an authenticated session; '
          'the AppBar action must show Profil, not Connexion.',
    );
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('home_create_private_button')), findsOneWidget);

    // =========================================================================
    // TC-E2E-09 — Navigate to ProfilePage and verify user information
    // =========================================================================
    //
    // Prerequisite: authenticated session established in TC-E2E-05.

    await goHome();

    await tester.tap(find.byKey(const Key('home_profile_button')));
    await waitFor(find.byType(ProfilePage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byKey(const Key('profile_display_name')), findsOneWidget);
    expect(find.text(testUsername), findsOneWidget);
    expect(find.byKey(const Key('profile_email')), findsOneWidget);
    expect(find.text(testEmail), findsOneWidget);
    expect(find.byKey(const Key('profile_role_badge')), findsOneWidget);
    expect(find.byKey(const Key('profile_member_since')), findsOneWidget);

    final logoutButton = tester.widget<FilledButton>(
      find.byKey(const Key('profile_logout_button')),
    );
    expect(
      logoutButton.onPressed,
      isNotNull,
      reason: 'Logout button must be enabled when no operation is in progress.',
    );

    expect(find.byKey(const Key('profile_back_button')), findsOneWidget);

    // Back navigation preserves the active session.
    await tester.tap(find.byKey(const Key('profile_back_button')));
    await waitFor(find.byType(HomePage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    expect(find.byKey(const Key('home_profile_button')), findsOneWidget);

    // =========================================================================
    // TC-E2E-10 — Logout from ProfilePage returns to unauthenticated HomePage
    // =========================================================================
    //
    // Prerequisite: authenticated session from TC-E2E-05, back on HomePage
    //               after TC-E2E-09.

    await tester.tap(find.byKey(const Key('home_profile_button')));
    await waitFor(find.byType(ProfilePage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('profile_logout_button')));

    await waitFor(
      find.byType(HomePage),
      timeout: const Duration(seconds: 20),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    expect(
      find.byKey(const Key('home_login_button')),
      findsOneWidget,
      reason:
      'After logout the AppBar action must revert to the Connexion button.',
    );
    expect(find.byKey(const Key('home_create_private_button')), findsNothing);
    expect(find.byKey(const Key('home_join_private_button')), findsOneWidget);

    // =========================================================================
    // TC-E2E-07 — Full login flow (real backend)
    // =========================================================================
    //
    // Prerequisite: unauthenticated state restored by TC-E2E-10 (logout).
    // Uses the account created during TC-E2E-05 (same testEmail / testPassword).
    //
    // TC-E2E-07 now executes last so that the unauthenticated state produced
    // by TC-E2E-10 provides direct access to [LoginPage] via the Connexion
    // button, without requiring an additional logout step.

    await goHome();

    await tester.tap(find.byKey(const Key('home_login_button')));
    await waitFor(find.byType(LoginPage));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextFormField).at(0), testEmail);
    await tester.enterText(find.byType(TextFormField).at(1), testPassword);

    await tester.tap(find.byKey(const Key('login_submit_button')));

    await waitFor(
      find.byType(HomePage),
      timeout: const Duration(seconds: 20),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    expect(
      find.byKey(const Key('home_profile_button')),
      findsOneWidget,
      reason: 'Authenticated state must expose the Profil action.',
    );
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('home_create_private_button')), findsOneWidget);
    expect(find.byKey(const Key('home_join_private_button')), findsOneWidget);
  });
}