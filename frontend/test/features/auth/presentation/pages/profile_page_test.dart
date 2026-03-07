import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_state.dart';
import 'package:youtogether/features/room/presentation/pages/home_page.dart';

// ---------------------------------------------------------------------------
// Fakes and helpers
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Minimal [GoRouter] that wraps [HomePage] without real navigation logic.
GoRouter _buildRouter(Widget home) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/login', builder: (_, __) => const _Stub('login')),
      GoRoute(path: '/profile', builder: (_, __) => const _Stub('profile')),
    ],
  );
}

class _Stub extends StatelessWidget {
  const _Stub(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(name));
}

UserEntity _fakeUser() => UserEntity(
  id: 'uid-1',
  email: 'alice@example.com',
  displayName: 'Alice',
  role: UserRole.authenticated,
  createdAt: DateTime(2026, 1, 1),
);

Widget _buildSubject(MockAuthBloc bloc) {
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(
      routerConfig: _buildRouter(const HomePage()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
  });

  // ── AppBar action button ──────────────────────────────────────────────────

  group('AppBar auth button', () {
    testWidgets(
      'shows "Connexion" when unauthenticated',
          (tester) async {
        when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());

        await tester.pumpWidget(_buildSubject(authBloc));

        expect(find.byKey(const Key('home_login_button')), findsOneWidget);
        expect(find.text('Connexion'), findsOneWidget);
        expect(find.byKey(const Key('home_profile_button')), findsNothing);
      },
    );

    testWidgets(
      'shows "Profil" when authenticated',
          (tester) async {
        when(() => authBloc.state)
            .thenReturn(AuthState.authenticated(user: _fakeUser()));

        await tester.pumpWidget(_buildSubject(authBloc));

        expect(find.byKey(const Key('home_profile_button')), findsOneWidget);
        expect(find.text('Profil'), findsOneWidget);
        expect(find.byKey(const Key('home_login_button')), findsNothing);
      },
    );

    testWidgets(
      'tapping "Connexion" navigates to /login',
          (tester) async {
        when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());

        await tester.pumpWidget(_buildSubject(authBloc));
        await tester.tap(find.byKey(const Key('home_login_button')));
        await tester.pumpAndSettle();

        expect(find.text('login'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Profil" navigates to /profile',
          (tester) async {
        when(() => authBloc.state)
            .thenReturn(AuthState.authenticated(user: _fakeUser()));

        await tester.pumpWidget(_buildSubject(authBloc));
        await tester.tap(find.byKey(const Key('home_profile_button')));
        await tester.pumpAndSettle();

        expect(find.text('profile'), findsOneWidget);
      },
    );
  });

  // ── Bottom action bar ─────────────────────────────────────────────────────

  group('Bottom action bar — unauthenticated', () {
    setUp(() {
      when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());
    });

    testWidgets(
      'shows "Rejoindre un groupe privé"',
          (tester) async {
        await tester.pumpWidget(_buildSubject(authBloc));

        expect(
          find.byKey(const Key('home_join_private_button')),
          findsOneWidget,
        );
        expect(find.text('Rejoindre un groupe privé'), findsOneWidget);
      },
    );

    testWidgets(
      'does NOT show "Créer un groupe privé"',
          (tester) async {
        await tester.pumpWidget(_buildSubject(authBloc));

        expect(
          find.byKey(const Key('home_create_private_button')),
          findsNothing,
        );
        expect(find.text('Créer un groupe privé'), findsNothing);
      },
    );
  });

  group('Bottom action bar — authenticated', () {
    setUp(() {
      when(() => authBloc.state)
          .thenReturn(AuthState.authenticated(user: _fakeUser()));
    });

    testWidgets(
      'shows both "Créer un groupe privé" and "Rejoindre un groupe privé"',
          (tester) async {
        await tester.pumpWidget(_buildSubject(authBloc));

        expect(
          find.byKey(const Key('home_create_private_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home_join_private_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"Créer un groupe privé" appears above "Rejoindre un groupe privé"',
          (tester) async {
        await tester.pumpWidget(_buildSubject(authBloc));

        final createY = tester
            .getTopLeft(find.byKey(const Key('home_create_private_button')))
            .dy;
        final joinY = tester
            .getTopLeft(find.byKey(const Key('home_join_private_button')))
            .dy;

        expect(createY, lessThan(joinY));
      },
    );
  });
}