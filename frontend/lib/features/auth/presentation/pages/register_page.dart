import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../bloc/register/register_cubit.dart';
import '../bloc/register/register_state.dart';

/// Account creation screen.
///
/// Managed by [RegisterCubit]. On [RegisterState.success] the screen pops
/// and the router / [AuthBloc] handles the subsequent navigation flow.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  /// Name route identifier.
  static const routeName = '/register';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Actions

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<RegisterCubit>().register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _onCancel() {
    context.read<RegisterCubit>().reset();
    Navigator.of(context).maybePop();
  }

  // Failure display

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

  // Build

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
      body: BlocListener<RegisterCubit, RegisterState>(
        listener: (context, state) {
          if (state is RegisterSuccess) {
            // Registration succeeded — pop back to login.
            // The router / AuthBloc will handle subsequent navigation.
            Navigator.of(context).maybePop();
          } else if (state is RegisterFailureState) {
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
                  // Vertical spacer
                  const Spacer(flex: 3),

                  // Heading
                  Text(
                    'Création de compte',
                    textAlign: TextAlign.center,
                    // style: AppTheme.displayTitle,
                  ),
                  const SizedBox(height: 24),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    // style: AppTheme.body,
                    decoration: const InputDecoration(
                      hintText: "nom d'utilisateur",
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Le nom d'utilisateur est requis.";
                      }
                      if (value.trim().length < 3) {
                        return "Le nom d'utilisateur doit contenir au moins 3 caractères.";
                      }
                      if (value.trim().length > 50) {
                        return "Le nom d'utilisateur ne peut pas dépasser 50 caractères.";
                      }
                      return null;
                    },
                  ),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newUsername],
                    // style: AppTheme.body,
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

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    // style: AppTheme.body,
                    decoration: InputDecoration(
                      hintText: 'mot de passe',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          // color: AppTheme.textSecondary,
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
                      if (value.length < 8) {
                        return 'Le mot de passe doit contenir au moins 8 caractères.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Confirm password Field
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _onSubmit(),
                    // style: AppTheme.body,
                    decoration: InputDecoration(
                      hintText: 'confirmer le mot de passe',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          // color: AppTheme.textSecondary,
                        ),
                        tooltip: _obscureConfirm
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez confirmer votre mot de passe.';
                      }
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Create account button
                  BlocBuilder<RegisterCubit, RegisterState>(
                    builder: (context, state) {
                      final isLoading = state is RegisterLoading;
                      return FilledButton(
                        onPressed: isLoading ? null : _onSubmit,
                        child: isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : const Text('Créer le compte'),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Cancel button
                  BlocBuilder<RegisterCubit, RegisterState>(
                    builder: (context, state) {
                      return OutlinedButton(
                        onPressed: state is RegisterLoading ? null : _onCancel,
                        child: const Text('Annuler'),
                      );
                    },
                  ),

                  // Bottom spacer
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
