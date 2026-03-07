import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/router/app_routes.dart';
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
///   ─ persistent bottom bar, which adapts to auth state:
///       • Authenticated   → "Créer un groupe privé" (top) +
///                           "Rejoindre un groupe privé" (bottom)
///       • Unauthenticated → "Rejoindre un groupe privé" only
///
/// The AppBar trailing action adapts to [AuthBloc] state:
///   - [AuthUnauthenticated] → "Connexion" → navigates to [LoginPage]
///   - [AuthAuthenticated]   → "Profil"    → navigates to [ProfilePage]
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
          // ── Tagline ──────────────────────────────────────────────────────
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

          // ── Section heading ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Groupes publics',
              textAlign: TextAlign.center,
              style: AppTheme.sectionHeading,
            ),
          ),
          const SizedBox(height: 12),

          // ── Room list ────────────────────────────────────────────────────
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

      // ── Bottom bar — adapts to authentication state ──────────────────────
      bottomNavigationBar: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isAuthenticated = state is AuthAuthenticated;
          return _BottomActionBar(
            isAuthenticated: isAuthenticated,
            onCreatePrivate: () => _onCreatePrivate(context),
            onJoinPrivate: () => _onJoinPrivate(context),
          );
        },
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
      context.push(AppRoutes.profile);
    } else {
      context.push(AppRoutes.login);
    }
  }

  void _onCreatePrivate(BuildContext context) {
    // Navigate to private room creation screen (route to be defined).
    // create-private route — to be defined
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
// Bottom action bar
// ---------------------------------------------------------------------------

/// Persistent bottom action bar that adapts to the user's authentication state.
///
/// Authenticated layout (top to bottom):
///   ─ "Créer un groupe privé"     (key: home_create_private_button)
///   ─ border
///   ─ "Rejoindre un groupe privé" (key: home_join_private_button)
///
/// Unauthenticated layout:
///   ─ "Rejoindre un groupe privé" only
///
/// Both rows maintain a fixed height of 56px, consistent with the original
/// single-row layout.
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isAuthenticated,
    required this.onCreatePrivate,
    required this.onJoinPrivate,
  });

  final bool isAuthenticated;
  final VoidCallback onCreatePrivate;
  final VoidCallback onJoinPrivate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardDark,
          border: Border(
            top: BorderSide(color: AppTheme.borderDark),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Créer un groupe privé" — visible only when authenticated.
            if (isAuthenticated) ...[
              _BarItem(
                key: const Key('home_create_private_button'),
                label: 'Créer un groupe privé',
                onTap: onCreatePrivate,
                style: _BarItemStyle.accent,
              ),
              const Divider(height: 1, color: AppTheme.borderDark),
            ],

            // "Rejoindre un groupe privé" — always visible.
            _BarItem(
              key: const Key('home_join_private_button'),
              label: 'Rejoindre un groupe privé',
              onTap: onJoinPrivate,
              style: _BarItemStyle.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bar item
// ---------------------------------------------------------------------------

enum _BarItemStyle { accent, muted }

class _BarItem extends StatelessWidget {
  const _BarItem({
    super.key,
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final _BarItemStyle style;

  @override
  Widget build(BuildContext context) {
    final color = style == _BarItemStyle.accent
        ? AppTheme.accent
        : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Center(
          child: Text(
            label,
            style: AppTheme.body.copyWith(
              color: color,
              fontWeight: style == _BarItemStyle.accent
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}