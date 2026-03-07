import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth/auth_state.dart';
import '../../features/auth/presentation/bloc/register/register_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/room/presentation/pages/home_page.dart';
import '../../injection_container.dart';
import 'app_routes.dart';

/// Creates and returns the application [GoRouter] wired to [authBloc].
///
/// [authBloc] is injected rather than read from the service locator so that
/// the router shares the exact same instance that [BlocProvider] exposes to
/// the widget tree. This guarantees that:
/// - [refreshListenable] fires whenever the bloc emits a new state.
/// - [redirect] reads the current state directly from the bloc instance
///   without relying on [BuildContext], avoiding the context/Navigator
///   ancestry constraint that caused the original [Navigator] error.
///
/// Route protection strategy:
/// - [protectedPaths] lists paths that require authentication.
/// - Unauthenticated access to a protected path redirects to [AppRoutes.login]
///   with a `redirect` query parameter so the user can be sent back after
///   logging in.
/// - Public paths ([AppRoutes.homePage], [AppRoutes.login],
///   [AppRoutes.register]) are accessible without a session.
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.homePage,

    // ── Reactive redirect ───────────────────────────────────────────────────
    //
    // [GoRouterRefreshStream] converts the BLoC stream into a [Listenable].
    // GoRouter re-evaluates [redirect] every time the stream emits — i.e.
    // on every [AuthState] transition — without requiring a manual navigation
    // call from the UI layer.
    refreshListenable: GoRouterRefreshStream(authBloc.stream),

    redirect: (context, state) {
      final authState = authBloc.state;
      final isUnauthenticated = authState is AuthUnauthenticated;

      // Paths that require an authenticated session.
      // Extend this list as protected features are added.
      const protectedPaths = <String>[];

      if (isUnauthenticated &&
          protectedPaths
              .any((path) => state.matchedLocation.startsWith(path))) {
        return '${AppRoutes.login}?redirect=${state.matchedLocation}';
      }

      return null;
    },

    // ── Route table ─────────────────────────────────────────────────────────
    routes: [
      GoRoute(
        path: AppRoutes.homePage,
        name: 'home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        // RegisterPage requires a fresh [RegisterCubit] scoped to the page
        // lifetime. The factory registration in the service locator guarantees
        // a new instance on each navigation.
        builder: (_, __) => BlocProvider<RegisterCubit>(
          create: (_) => sl<RegisterCubit>(),
          child: const RegisterPage(),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// GoRouterRefreshStream
// ---------------------------------------------------------------------------

/// Adapts a [Stream] to [ChangeNotifier] so that [GoRouter.refreshListenable]
/// can react to BLoC state changes.
///
/// Each emission on [stream] calls [notifyListeners], which causes GoRouter
/// to re-evaluate its [redirect] callback. The subscription is cancelled in
/// [dispose] to prevent memory leaks.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}