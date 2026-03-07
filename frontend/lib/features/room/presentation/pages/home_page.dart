import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/app_theme.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth/auth_state.dart';

import '../../../room/domain/entities/room_entity.dart';

/// Home screen — public room listing.
///
/// Layout (top to bottom, matching wireframe):
///   AppBar "YouTogether" + action [Connexion | Profil]
///   ─ tagline "Regardez des vidéos YouTube ensemble en temps réel"
///   ─ "GROUPES PUBLICS" section heading
///   ─ scrollable list of [_RoomCard] items (name + member count)
///   ─ persistent bottom bar [Rejoindre un groupe privé]
///
/// The AppBar trailing action adapts to [AuthBloc] state:
/// - [AuthUnauthenticated] → "Connexion" → navigates to [LoginPage]
/// - [AuthAuthenticated]   → "Profil" → navigates to the profile screen
///
/// The room list is provided via constructor for now; it will be driven by
/// [RoomBloc] once that feature is integrated.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.rooms = const [],
  });

  /// Public rooms to display. Driven by [RoomBloc] in production.
  final List<RoomEntity> rooms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTogether'),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isAuthenticated = state is AuthAuthenticated;
              return TextButton(
                key: isAuthenticated
                    ? const Key('home_profile_button')
                    : const Key('home_login_button'),
                onPressed: () => _onAuthAction(context, state),
                child: Text(
                  isAuthenticated ? 'Profil' : 'Connexion',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tagline ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              'Regardez des vidéos YouTube\nensemble en temps réel',
              style: AppTheme.body.copyWith(
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Section heading ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Groupes publics',
              textAlign: TextAlign.center,
              style: AppTheme.sectionHeading,
            ),
          ),
          const SizedBox(height: 12),

          // ── Room list ──────────────────────────────────────────────────
          Expanded(
            child: rooms.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _RoomCard(room: rooms[index]);
              },
            ),
          ),
        ],
      ),

      // ── Bottom bar: Rejoindre un groupe privé ───────────────────────────
      bottomNavigationBar: _BottomJoinBar(
        onTap: () => _onJoinPrivate(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Aucun groupe public disponible pour le moment.',
        textAlign: TextAlign.center,
        style: AppTheme.caption,
      ),
    );
  }

  void _onAuthAction(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      // Navigate to profile screen (route to be defined).
      context.push(AppRoutes.homePage); // profile route — to be defined
    } else {
      context.push(AppRoutes.login);
    }
  }

  void _onJoinPrivate(BuildContext context) {
    // Navigate to private room join screen (route to be defined).
    // join-private route — to be defined
  }
}

// ---------------------------------------------------------------------------
// Room card widget
// ---------------------------------------------------------------------------

/// A single row in the public room listing.
///
/// Displays the room [name] on the left and the member [memberCount]
/// with a group icon on the right, matching the wireframe layout.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final RoomEntity room;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardDark,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => context.push('/room', extra: room.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              // Room name
              Expanded(
                child: Text(
                  room.name,
                  style: AppTheme.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

              // Member count indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // Member count is not yet available in RoomEntity MVP.
                    // The field will be added to the domain model in a later
                    // iteration; a placeholder value is shown in the interim.
                    '—',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom join bar
// ---------------------------------------------------------------------------

class _BottomJoinBar extends StatelessWidget {
  const _BottomJoinBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            border: Border(
              top: BorderSide(color: AppTheme.borderDark),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'Rejoindre un groupe privé',
            style: AppTheme.body.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}