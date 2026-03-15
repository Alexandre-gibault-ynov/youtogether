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
/// Layout (top to bottom):
///   AppBar "YouTogether" + action [Connexion | Profil]
///   ─ tagline
///   ─ section heading
///   ─ scrollable list of [_RoomCard] (Expanded — fills remaining space)
///   ─ private-group action buttons (in body, not in bottomNavigationBar):
///       • Authenticated   → "Créer un groupe privé" + "Rejoindre un groupe privé"
///       • Unauthenticated → "Rejoindre un groupe privé" only
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tagline ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'Regardez des vidéos YouTube\nensemble en temps réel',
                style: AppTheme.body.copyWith(fontSize: 17, height: 1.4),
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
                itemBuilder: (context, index) =>
                    _RoomCard(room: rooms[index]),
              ),
            ),

            // ── Private-group action buttons ───────────────────────────────
            //
            // Positioned inside the body (not in Scaffold.bottomNavigationBar)
            // to avoid overlap with the Android gesture navigation bar.
            // Buttons are centered with horizontal padding so they do not
            // span the full screen width, matching the wireframe layout.
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isAuthenticated = state is AuthAuthenticated;
                return _PrivateGroupActions(
                  isAuthenticated: isAuthenticated,
                  onCreatePrivate: () => _onCreatePrivate(context),
                  onJoinPrivate: () => _onJoinPrivate(context),
                );
              },
            ),
          ],
        ),
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
  }

  void _onJoinPrivate(BuildContext context) {
    // Navigate to private room join screen (route to be defined).
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
// Private group action buttons
// ---------------------------------------------------------------------------

/// Section displayed below the room list for private-group actions.
///
/// The buttons are rendered as [OutlinedButton] with a constrained max width
/// and horizontal margin so they do not span the full screen width, in
/// accordance with the wireframe layout.
///
/// A top [Divider] visually separates this section from the room list.
/// Bottom padding is driven by [SafeArea] (applied on the parent [body])
/// so the buttons remain above the Android gesture navigation bar.
class _PrivateGroupActions extends StatelessWidget {
  const _PrivateGroupActions({
    required this.isAuthenticated,
    required this.onCreatePrivate,
    required this.onJoinPrivate,
  });

  final bool isAuthenticated;
  final VoidCallback onCreatePrivate;
  final VoidCallback onJoinPrivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppTheme.borderDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Créer un groupe privé" — authenticated only.
              if (isAuthenticated) ...[
                _ActionButton(
                  key: const Key('home_create_private_button'),
                  label: 'Créer un groupe privé',
                  onTap: onCreatePrivate,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 10),
              ],

              // "Rejoindre un groupe privé" — always visible.
              _ActionButton(
                key: const Key('home_join_private_button'),
                label: 'Rejoindre un groupe privé',
                onTap: onJoinPrivate,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single action button in the private-group section.
///
/// Rendered as an [OutlinedButton] at full width within its parent padding,
/// which already constrains the visual width away from the screen edges.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ),
    );
  }
}