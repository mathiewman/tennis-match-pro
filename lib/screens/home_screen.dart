import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/player_model.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';
import 'register_club_screen.dart';
import 'club_dashboard_screen.dart';
import 'matchmaking_screen.dart';
import 'club_explorer_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final String role = userData['role'] ?? 'player';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1A),
      body: _buildBodyForRole(context, role, user),
      floatingActionButton: role == 'admin'
          ? FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
        backgroundColor: const Color(0xFFCCFF00),
        child: const Icon(Icons.admin_panel_settings,
            color: Color(0xFF0D1F1A)),
      )
          : null,
    );
  }

  Widget _buildBodyForRole(BuildContext context, String role, User user) {
    if (role == 'coordinator') {
      return _CoordinatorHome(user: user, userData: userData);
    }
    if (role == 'admin') {
      return _AdminHome(user: user);
    }
    return _PlayerHome(user: user);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER HOME — dashboard completo del jugador
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerHome extends StatelessWidget {
  final User user;
  const _PlayerHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DatabaseService().getPlayerStream(user.uid),
      builder: (context, snap) {
        Player? player;
        if (snap.hasData && snap.data!.exists) {
          player = Player.fromFirestore(snap.data!);
        }

        return CustomScrollView(
          slivers: [
            // ── HEADER ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PlayerHeader(user: user, player: player),
            ),

            // ── STATS RÁPIDAS ────────────────────────────────────────────────
            if (player != null)
              SliverToBoxAdapter(
                child: _QuickStats(player: player),
              ),

            // ── BOTÓN PRINCIPAL ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _MainActionButton(player: player, context: context),
            ),

            // ── ACCESOS RÁPIDOS ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _QuickActions(context: context),
            ),

            // ── RANKING SNAPSHOT ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _RankingSnapshot(uid: user.uid),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER DEL JUGADOR
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerHeader extends StatelessWidget {
  final User   user;
  final Player? player;
  const _PlayerHeader({required this.user, this.player});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL ?? player?.photoUrl ?? '';
    final name     = user.displayName ?? 'Jugador';
    final level    = player?.tennisLevel ?? '';
    final elo      = player?.eloRating ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A3A34), Color(0xFF0D1F1A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TENNIS MATCH PRO',
                    style: TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5)),
                const SizedBox(height: 2),
                Text('Hola, ${name.split(' ').first} 👋',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ]),
              Row(children: [
                // Logout
                GestureDetector(
                  onTap: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login', (r) => false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout,
                        color: Colors.white54, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFCCFF00), width: 2),
                      image: photoUrl.isNotEmpty
                          ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover)
                          : null,
                    ),
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person,
                        color: Colors.white70, size: 24)
                        : null,
                  ),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 24),

          // ELO + nivel
          Row(children: [
            // ELO card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFCCFF00).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ELO',
                      style: TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  Text(
                    elo.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Nivel
            if (level.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NIVEL',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 2),
                    Text(level,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS RÁPIDAS (PJ / PG / PP / %G)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickStats extends StatelessWidget {
  final Player player;
  const _QuickStats({required this.player});

  @override
  Widget build(BuildContext context) {
    // Buscar stats del último torneo en annual_stats
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(player.id)
          .collection('match_history')
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        // Mostramos stats del player model si existen
        // (en futuro se pueden enriquecer con datos de torneos)
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('COINS', '${player.balance_coins}',
                    const Color(0xFFCCFF00), Icons.monetization_on),
                _divider(),
                _statItem('NIVEL', player.tennisLevel, Colors.blueAccent,
                    Icons.emoji_events),
                _divider(),
                _statItem('ESTADO',
                    player.status == 'disponible' ? 'LIBRE' : 'OCUPADO',
                    player.status == 'disponible'
                        ? Colors.greenAccent
                        : Colors.white38,
                    Icons.circle),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 9, letterSpacing: 1)),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 40,
      color: Colors.white.withOpacity(0.08));
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class _MainActionButton extends StatelessWidget {
  final Player?  player;
  final BuildContext context;
  const _MainActionButton({this.player, required this.context});

  @override
  Widget build(BuildContext context) {
    final isAvailable = player?.status == 'disponible';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: GestureDetector(
        onTap: isAvailable
            ? () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MatchmakingScreen()))
            : () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: isAvailable
                ? const LinearGradient(
              colors: [Color(0xFFCCFF00), Color(0xFFAADD00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isAvailable ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: isAvailable
                ? null
                : Border.all(color: Colors.white12),
            boxShadow: isAvailable
                ? [
              BoxShadow(
                color: const Color(0xFFCCFF00).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAvailable
                    ? Icons.sports_tennis
                    : Icons.toggle_off_outlined,
                color: isAvailable ? Colors.black : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                isAvailable ? 'BUSCAR PARTIDO' : 'ACTIVAR DISPONIBILIDAD',
                style: TextStyle(
                  color: isAvailable ? Colors.black : Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCESOS RÁPIDOS
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final BuildContext context;
  const _QuickActions({required this.context});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('ACCESOS RÁPIDOS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),
          Row(children: [
            Expanded(child: _actionTile(
              context,
              icon: Icons.person,
              label: 'MI PERFIL',
              color: Colors.blueAccent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _actionTile(
              context,
              icon: Icons.stadium,
              label: 'CLUBES',
              color: Colors.purpleAccent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ClubExplorerScreen())),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context,
      {required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANKING SNAPSHOT — top 5 del ranking anual
// ─────────────────────────────────────────────────────────────────────────────
class _RankingSnapshot extends StatelessWidget {
  final String uid;
  const _RankingSnapshot({required this.uid});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('RANKING ${ "" }',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),

          // Buscar en todos los clubes el ranking anual
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('annual_stats')
                .where(FieldPath.documentId, isEqualTo: year)
                .limit(1)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return _emptyRanking();
              }

              final raw = (snap.data!.docs.first.data()
              as Map<String, dynamic>)['players'] as List? ??
                  [];

              if (raw.isEmpty) return _emptyRanking();

              // Ordenar por totalPts
              final players = raw
                  .map((p) => Map<String, dynamic>.from(p))
                  .toList()
                ..sort((a, b) =>
                    ((b['totalPts'] ?? 0) as int)
                        .compareTo((a['totalPts'] ?? 0) as int));

              final top5 = players.take(5).toList();

              // Posición del usuario actual
              final myPos = players.indexWhere((p) {
                final phone = (p['phone'] ?? '').toString();
                return phone.isNotEmpty;
                // Simplificado — en producción comparar por nameKey
              });

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Column(
                  children: [
                    ...top5.asMap().entries.map((entry) {
                      final i    = entry.key;
                      final p    = entry.value;
                      final name = (p['name'] ?? '').toString();
                      final pts  = (p['totalPts'] ?? 0) as int;
                      final isMe = p['phone'] != null &&
                          p['phone'].toString().isNotEmpty &&
                          i == myPos;

                      return _rankRow(i + 1, name, pts, isMe,
                          i < top5.length - 1);
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _rankRow(
      int pos, String name, int pts, bool isMe, bool showDivider) {
    final Color posColor = pos == 1
        ? const Color(0xFFFFD700)
        : pos == 2
        ? const Color(0xFFC0C0C0)
        : pos == 3
        ? const Color(0xFFCD7F32)
        : Colors.white38;

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFCCFF00).withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          // Posición
          SizedBox(
            width: 28,
            child: Text(
              pos <= 3 ? ['🥇', '🥈', '🥉'][pos - 1] : '$pos',
              style: TextStyle(
                  color: posColor,
                  fontSize: pos <= 3 ? 18 : 12,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Nombre
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                color: isMe ? const Color(0xFFCCFF00) : Colors.white70,
                fontSize: 12,
                fontWeight:
                isMe ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Pts
          Text(
            '$pts PTS',
            style: TextStyle(
              color: isMe ? const Color(0xFFCCFF00) : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (isMe)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.arrow_right,
                  color: Color(0xFFCCFF00), size: 14),
            ),
        ]),
      ),
      if (showDivider)
        Divider(
            height: 1,
            color: Colors.white.withOpacity(0.05),
            indent: 16,
            endIndent: 16),
    ]);
  }

  Widget _emptyRanking() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: const Center(
        child: Text('Sin torneos publicados este año',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COORDINATOR HOME
// ─────────────────────────────────────────────────────────────────────────────
class _CoordinatorHome extends StatelessWidget {
  final User                 user;
  final Map<String, dynamic> userData;
  const _CoordinatorHome({required this.user, required this.userData});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A34), Color(0xFF0D1F1A)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('COORDINADOR',
                      style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 4),
                  Text(
                    user.displayName?.split(' ').first ?? 'Coordinador',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login', (r) => false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.lightBlueAccent, width: 2),
                      image: (user.photoURL ?? '').isNotEmpty
                          ? DecorationImage(
                          image: NetworkImage(user.photoURL!),
                          fit: BoxFit.cover)
                          : null,
                    ),
                    child: (user.photoURL ?? '').isEmpty
                        ? const Icon(Icons.person,
                        color: Colors.white70, size: 24)
                        : null,
                  ),
                ]),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: DatabaseService().getClubByOwner(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFCCFF00)));
                }

                final clubData = snapshot.data;

                if (clubData == null) {
                  return _NoClubCard(context: context);
                }

                return _ClubCard(clubData: clubData, context: context);
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _NoClubCard extends StatelessWidget {
  final BuildContext context;
  const _NoClubCard({required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        const Icon(Icons.add_business,
            color: Color(0xFFCCFF00), size: 48),
        const SizedBox(height: 16),
        const Text('Todavía no tenés un club registrado',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Registrá tu sede para gestionar canchas y torneos.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RegisterClubScreen())),
          icon: const Icon(Icons.add),
          label: const Text('REGISTRAR MI CLUB'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCFF00),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final Map<String, dynamic> clubData;
  final BuildContext         context;
  const _ClubCard({required this.clubData, required this.context});

  @override
  Widget build(BuildContext context) {
    final clubId   = clubData['id'] ?? '';
    final name     = (clubData['name'] ?? 'Mi Club').toString();
    final address  = clubData['address'] ?? '';
    final photoUrl = clubData['photoUrl'] ?? clubData['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ClubDashboardScreen(clubId: clubId))),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFFCCFF00).withOpacity(0.4), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // Foto de fondo
            if (photoUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(photoUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.5),
                    colorBlendMode: BlendMode.darken),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF1A3A34),
                  child: const Icon(Icons.stadium,
                      color: Colors.white10, size: 80),
                ),
              ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFF00),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('MI SEDE',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  if (address.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFFCCFF00), size: 12),
                      const SizedBox(width: 4),
                      Text(address,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
                ],
              ),
            ),

            // Flecha
            const Positioned(
              right: 20, top: 20,
              child: Icon(Icons.arrow_forward_ios,
                  color: Color(0xFFCCFF00), size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN HOME
// ─────────────────────────────────────────────────────────────────────────────
class _AdminHome extends StatelessWidget {
  final User user;
  const _AdminHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A34), Color(0xFF0D1F1A)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ADMINISTRADOR',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 4),
                  Text(
                    user.displayName?.split(' ').first ?? 'Admin',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                GestureDetector(
                  onTap: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login', (r) => false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout,
                        color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PANEL DE CONTROL',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 16),
                _adminTile(context,
                    icon: Icons.admin_panel_settings,
                    label: 'PANEL ADMIN',
                    subtitle: 'Coins, usuarios ficticios',
                    color: Colors.amber,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPanelScreen()))),
                const SizedBox(height: 12),
                _adminTile(context,
                    icon: Icons.stadium,
                    label: 'EXPLORAR CLUBES',
                    subtitle: 'Ver todos los clubes',
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ClubExplorerScreen()))),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _adminTile(BuildContext context,
      {required IconData icon,
        required String label,
        required String subtitle,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}