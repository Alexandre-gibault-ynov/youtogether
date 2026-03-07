import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

/// Login screen — "Connexion".
///
/// Navigation is handled exclusively via [GoRouter]:
/// - "Créer un compte" → [context.push] to [AppRoutes.register]
/// - "Annuler"         → [context.pop]
/// - [AuthAuthenticated] emitted by [AuthBloc] → [context.go] to [AppRoutes.homePage]
///
/// [AuthBloc] is provided by the ancestor [BlocProvider] registered in
/// [app_router.dart]; no local provider is needed here.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthEvent.loginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  void _onCancel() {
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    if (context.canPop()) context.pop();
  }

  void _onCreateAccount() {
    context.push(AppRoutes.register);
  }

  // ---------------------------------------------------------------------------
  // Failure display
  // ---------------------------------------------------------------------------

  String _failureMessage(Failure failure) {
    return switch (failure) {
      AuthFailure(:final message) => message,
      NetworkFailure() =>
      'Aucune connexion Internet. Vérifiez votre réseau et réessayez.',
      ServerFailure(:final statusCode) =>
      'Erreur serveur ($statusCode). Veuillez réessayer plus tard.',
      ValidationFailure(:final errors) => errors.values.join('\n'),
      _ => 'Une erreur inattendue est survenue. Veuillez réessayer.',
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTogether'),
        automaticallyImplyLeading: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Login succeeded — navigate to home and clear the back stack.
            context.go(AppRoutes.homePage);
          } else if (state is AuthFailureState) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(_failureMessage(state.failure)),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),

                  // ── Heading ──────────────────────────────────────────────
                  Text(
                    key: const Key('login_heading'),
                    'Connexion',
                    textAlign: TextAlign.center,
                    style: AppTheme.displayTitle,
                  ),
                  const SizedBox(height: 24),

                  // ── Email ─────────────────────────────────────────────────
                  TextFormField(
                    key: const Key('login_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    style: AppTheme.body,
                    decoration: const InputDecoration(hintText: 'email'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "L'adresse email est requise.";
                      }
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Veuillez saisir une adresse email valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Password ──────────────────────────────────────────────
                  TextFormField(
                    key: const Key('login_password_field'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _onSubmit(),
                    style: AppTheme.body,
                    decoration: InputDecoration(
                      hintText: 'mot de passe',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le mot de passe est requis.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Se connecter ──────────────────────────────────────────
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return FilledButton(
                        key: const Key('login_submit_button'),
                        onPressed: isLoading ? null : _onSubmit,
                        child: isLoading
                            ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                            : const Text('Se connecter'),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Annuler ───────────────────────────────────────────────
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return OutlinedButton(
                        key: const Key('login_cancel_button'),
                        onPressed: state is AuthLoading ? null : _onCancel,
                        child: const Text('Annuler'),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── Pas de compte ? ───────────────────────────────────────
                  Text(
                    'Pas de compte ?',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption,
                  ),
                  const SizedBox(height: 10),

                  // ── Créer un compte ───────────────────────────────────────
                  OutlinedButton(
                    key: const Key('login_create_account_button'),
                    onPressed: _onCreateAccount,
                    child: const Text('Créer un compte'),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}