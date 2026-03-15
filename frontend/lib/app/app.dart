import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';
import '../core/router/app_router.dart';
import '../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth/auth_event.dart';
import '../injection_container.dart';

/// Root widget of the YouTogether application.
///
/// Responsibilities:
/// - Owns the single [AuthBloc] instance for the application lifetime.
/// - Passes that instance to both [BlocProvider] (widget tree) and
///   [createRouter] (navigation layer) so both share the same state.
/// - Mounts [MaterialApp.router] configured with [GoRouter].
///
/// [AuthBloc] is created here as a [StatefulWidget] field rather than
/// inside [BlocProvider.create] so its reference can be forwarded to
/// [createRouter]. [BlocProvider.value] is used instead of
/// [BlocProvider.create] because this widget owns the lifecycle
/// (creation + disposal) explicitly.
///
/// Navigation strategy (enforced in [app_router.dart]):
/// - [AppRoutes.homePage] (`/`) is the initial route and is public.
/// - Protected paths redirect to [AppRoutes.login] when unauthenticated.
/// - [GoRouterRefreshStream] re-evaluates redirect on every [AuthState]
///   emission — no manual navigation calls are needed from the UI layer.
class YouTogether extends StatefulWidget {
  const YouTogether({super.key});

  @override
  State<YouTogether> createState() => _YouTougetherState();
}

class _YouTougetherState extends State<YouTogether> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Instantiate the bloc and immediately check for an existing session.
    _authBloc = sl<AuthBloc>()
      ..add(const AuthEvent.checkStatusRequested());

    // Wire the router to the same bloc instance.
    _router = createRouter(_authBloc);
  }

  @override
  void dispose() {
    // GoRouter disposes GoRouterRefreshStream (which cancels the subscription).
    _router.dispose();
    // AuthBloc is owned here — close it explicitly.
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // BlocProvider.value — ownership (and disposal) remains with this State.
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'YouTogether',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}