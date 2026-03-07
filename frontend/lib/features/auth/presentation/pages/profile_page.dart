import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

/// Displays the authenticated user's profile information and provides a
/// logout action.
///
/// The page is only reachable when [AuthAuthenticated] is the current state.
/// [app_router.dart] enforces this invariant by redirecting unauthenticated
/// access to [AppRoutes.login].
///
/// Layout (top to bottom):
///   AppBar with back navigation
///   ─ Avatar circle (initials fallback)
///   ─ Display name
///   ─ Email
///   ─ Role badge
///   ─ Member-since date
///   ─ [Spacer]
///   ─ "Se déconnecter" primary button
///
/// User profile editing is deferred to a later iteration.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Navigate away when the session is cleared.
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/');
        }
      },
      builder: (context, state) {
        // Guard: if the state is somehow not authenticated, show nothing.
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _ProfileView(user: state.user);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal layout widget
// ---------------------------------------------------------------------------

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: BackButton(
          key: const Key('profile_back_button'),
          onPressed: () => context.pop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Display name ─────────────────────────────────────────────
              Text(
                user.displayName,
                key: const Key('profile_display_name'),
                style: AppTheme.displayTitle.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // ── Email ────────────────────────────────────────────────────
              Text(
                user.email,
                key: const Key('profile_email'),
                style: AppTheme.caption.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // ── Role badge ───────────────────────────────────────────────
              _RoleBadge(role: user.role),

              const SizedBox(height: 20),

              // ── Member since ─────────────────────────────────────────────
              _MemberSince(date: user.createdAt),

              const Spacer(),

              // ── Logout ───────────────────────────────────────────────────
              _LogoutButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  String get _label {
    switch (role) {
      case UserRole.authenticated:
        return 'Membre';
      default:
        UserRole.guest;
        return 'Invité';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profile_role_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Text(
        _label,
        style: AppTheme.caption.copyWith(
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member since
// ---------------------------------------------------------------------------

class _MemberSince extends StatelessWidget {
  const _MemberSince({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('d MMMM yyyy', 'fr_FR').format(date);

    return Text(
      'Membre depuis le $formatted',
      key: const Key('profile_member_since'),
      style: AppTheme.caption,
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Logout button
// ---------------------------------------------------------------------------

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthBloc>().state is AuthLoading;

    return FilledButton(
      key: const Key('profile_logout_button'),
      onPressed: isLoading
          ? null
          : () => context
          .read<AuthBloc>()
          .add(const AuthEvent.logoutRequested()),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: isLoading
          ? const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : const Text(
        'Se déconnecter',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}