import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtogether/core/router/app_routes.dart';

import '../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';

/// Application router.
/// Redirect logic is driven exclusively by [AuthBloc] state.
/// No route performs its own authentication check.
final router = GoRouter(
  initialLocation: AppRoutes.homePage,
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isUnauthenticated = authState is AuthUnauthenticated;

    // Authentication needed
    final protectedPaths = [];

    if (isUnauthenticated &&
        protectedPaths.any((path) => state.matchedLocation.startsWith(path))) {
      return '${AppRoutes.login}?redirect=${state.matchedLocation}';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (_, _) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (_, _) => const RegisterPage(),
    ),
  ],
);
