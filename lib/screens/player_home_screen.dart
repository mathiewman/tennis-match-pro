import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../models/tournament_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/push_notification_service.dart';
import '../services/theme_service.dart';
import '../constants/theme_colors.dart';
import 'matchmaking_screen.dart';
import 'club_profile_screen.dart';
import 'club_store_screen.dart';
import 'player_booking_screen.dart';
import 'tournament_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR POR CATEGORÍA — usado en toda la app
// ─────────────────────────────────────────────────────────────────────────────
Color catColor(String category) {
  switch (category) {
    case '1era': return const Color(0xFFFFD700); // Oro
    case '2nda': return const Color(0xFFB8C4CC); // Plata
    case '3era': return const Color(0xFFCD7F32); // Bronce
    case '4ta':  return const Color(0xFF00D4AA); // Esmeralda
    case '5ta':  return const Color(0xFF5B9CF6); // Azul
    case '6ta':  return const Color(0xFF9CA3AF); // Gris
    default:     return Colors.white54;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHELL PRINCIPAL — controla los 4 tabs
// ─────────────────────────────────────────────────────────────────────────────
class PlayerHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  static int? pendingCourtsSubTab; // for navigating directly to MIS RESERVAS sub-tab
  const PlayerHomeScreen({super.key, required this.userData});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  void _goToTab(int i) => setState(() => _tab = i);

  @override
  void initState() {
    super.initState();
    // Registrar callback para notificaciones mientras la app está activa
    PushNotificationService.onNavigateToTab = (tab) {
      if (mounted) setState(() => _tab = tab);
    };
    // Navegar al tab si la app fue abierta desde una notificación (estaba cerrada)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = PushNotificationService.pendingHomeTab;
      if (pending != null && mounted) {
        setState(() => _tab = pending);
        PushNotificationService.pendingHomeTab = null;
      }
    });
  }

  @override
  void dispose() {
    PushNotificationService.onNavigateToTab = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      body: IndexedStack(
        index: _tab,
        children: [
          _ProfileTab(
            uid: uid,
            onGoToMatchmaking: () => _goToTab(1),
            onGoToReservas: () {
              PlayerHomeScreen.pendingCourtsSubTab = 1; // navigate to MIS RESERVAS sub-tab
              _goToTab(2);
            },
          ),
          MatchmakingScreen(
            onBack:      () => _goToTab(0),
            homeClubId:  widget.userData['homeClubId']?.toString() ?? '',
          ),
          _CourtsTab(uid: uid),
          _TournamentsTab(
            uid:          uid,
            userCategory: widget.userData['category']?.toString() ?? '',
            homeClubId:   widget.userData['homeClubId']?.toString() ?? '',
          ),
          _StoreTab(uid: uid),
        ],
      ),
      bottomNavigationBar: _BottomNav(
          current: _tab, onTap: _goToTab),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(top: BorderSide(color: c.navBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _item(context, 0, Icons.person_outline, Icons.person, 'PERFIL'),
              _item(context, 1, Icons.sports_tennis_outlined,
                  Icons.sports_tennis, 'JUGAR'),
              _item(context, 2, Icons.calendar_month_outlined,
                  Icons.calendar_month, 'RESERVAS'),
              _item(context, 3, Icons.emoji_events_outlined,
                  Icons.emoji_events, 'TORNEOS'),
              _item(context, 4, Icons.storefront_outlined,
                  Icons.storefront, 'TIENDA'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData off, IconData on, String label) {
    final sel = current == i;
    final c = TC.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador activo
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: sel ? 32 : 0,
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: TC.lime,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(sel ? on : off,
                color: sel ? TC.lime : c.navUnselected,
                size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: sel ? TC.lime : c.navUnselected,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB PERFIL — diseño completo
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  final String uid;
  final VoidCallback onGoToMatchmaking;
  final VoidCallback onGoToReservas;
  const _ProfileTab({required this.uid, required this.onGoToMatchmaking, required this.onGoToReservas});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _db = DatabaseService();

  // Stats cacheados
  int _pj = 0, _pg = 0, _pts = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    int pj = 0, pg = 0, pts = 0;
    try {
      final name = (FirebaseAuth.instance.currentUser?.displayName ?? '')
          .toUpperCase();
      final snap = await FirebaseFirestore.instance
          .collectionGroup('annual_stats')
          .limit(30)
          .get();
      for (final doc in snap.docs) {
        final players = (doc.data()['players'] as List?) ?? [];
        for (final p in players) {
          final pName = (p['name'] ?? '').toString().toUpperCase();
          if (pName == name || p['uid']?.toString() == widget.uid) {
            pj  += ((p['pj']       ?? 0) as num).toInt();
            pg  += ((p['pg']       ?? 0) as num).toInt();
            pts += ((p['totalPts'] ?? p['rankingPts'] ?? 0) as num).toInt();
          }
        }
      }
    } catch (e) {
      debugPrint('[PlayerProfile] Error loading stats: $e');
    }
    if (mounted) setState(() {
      _pj = pj; _pg = pg; _pts = pts; _statsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.getPlayerStream(widget.uid),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: CircularProgressIndicator(
              color: Color(0xFFCCFF00)));
        }
        final player = Player.fromFirestore(snap.data!);
        final playerCategory = player.category ?? '';

        final c = TC.of(context);
        return RefreshIndicator(
          color: TC.lime,
          backgroundColor: c.scaffold2,
          onRefresh: _loadStats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            children: [
              _buildHero(player, playerCategory),
              const SizedBox(height: 16),
              _buildClubBanner(),
              _buildMisReservasShortcut(),
              _buildPlayerDetails(player),
              _buildStatsRow(player),
              _buildThemeToggle(),
              _buildMatchHistory(),
            ],
          ),
        );
      },
    );
  }

  // ── CLUB BANNER ──────────────────────────────────────────────────────────
  Widget _buildClubBanner() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data       = snap.data!.data() as Map<String, dynamic>? ?? {};
        final homeClubId = data['homeClubId']?.toString() ?? '';
        final clubName   = data['homeClubName']?.toString() ?? '';

        if (homeClubId.isNotEmpty) {
          // Mostrar club actual (compacto, tappable)
          return GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => ClubProfileScreen(clubId: homeClubId),
            )),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFCCFF00).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.stadium_outlined,
                      color: Color(0xFFCCFF00), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clubName.isNotEmpty ? clubName : 'Mi Club',
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Builder(builder: (ctx2) {
                    final c2 = TC.of(ctx2);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('MI CLUB',
                          style: TextStyle(
                              color: c2.text24,
                              fontSize: 9,
                              letterSpacing: 1)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right,
                          color: c2.text24, size: 14),
                    ]);
                  }),
                ]),
              ),
            ),
          );
        }

        // Sin club → banner de alerta
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Seleccioná tu club en EDITAR PERFIL para ver reservas y jugadores.',
                  style: TextStyle(color: Colors.orange, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── MIS RESERVAS SHORTCUT ────────────────────────────────────────────────
  Widget _buildMisReservasShortcut() {
    final c = TC.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GestureDetector(
        onTap: widget.onGoToReservas,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined,
                color: Colors.blueAccent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('MIS RESERVAS',
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            _ReservasCountBadge(uid: widget.uid),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: c.text24, size: 14),
          ]),
        ),
      ),
    );
  }

  // ── HERO ─────────────────────────────────────────────────────────────────
  Widget _buildHero(Player player, String playerCategory) {
    // Foto de perfil de la app — independiente de la foto de Google
    final appPhoto = (player.photoUrl != null && player.photoUrl!.isNotEmpty)
        ? player.photoUrl!
        : '';
    // Foto de Google (solo para mostrar en indicador de cuenta vinculada)
    final googlePhoto = FirebaseAuth.instance.currentUser?.photoURL ?? '';
    final photo = appPhoto; // El avatar principal usa solo la foto de la app
    final eloData = _eloData(player.eloRating);
    final c = TC.of(context);

    return SizedBox(
      height: 320,
      child: Stack(children: [

        // Fondo con cancha dibujada
        Positioned.fill(
          child: CustomPaint(painter: _HeroPainter(isDark: Theme.of(context).brightness == Brightness.dark)),
        ),

        // Gradiente inferior para transición
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, c.scaffold],
              ),
            ),
          ),
        ),

        // Contenido del hero
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Fila superior: editar + logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _showEditModal(context, player),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.edit_outlined,
                              color: c.text38, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _confirmLogout(player),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.logout,
                              color: c.text38, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Avatar + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar principal — foto de perfil de la app
                      GestureDetector(
                        onTap: () => _showEditModal(context, player),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: photo.isNotEmpty
                                        ? const Color(0xFFCCFF00)
                                        : Colors.white24,
                                    width: photo.isNotEmpty ? 3 : 1.5),
                                boxShadow: photo.isNotEmpty ? [
                                  BoxShadow(
                                    color: const Color(0xFFCCFF00)
                                        .withOpacity(0.35),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ] : [],
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: c.surface,
                                backgroundImage: photo.isNotEmpty
                                    ? NetworkImage(photo) : null,
                                child: photo.isEmpty
                                    ? Icon(Icons.camera_alt,
                                        size: 28, color: c.text38)
                                    : null,
                              ),
                            ),
                            // Badge "+" para indicar que se puede subir foto
                            if (photo.isEmpty)
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCCFF00),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add,
                                      size: 12, color: Colors.black),
                                ),
                              ),
                            // Indicador cuenta Google (pequeño)
                            if (googlePhoto.isNotEmpty)
                              Positioned(
                                top: 0, right: 0,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: c.scaffold,
                                        width: 2),
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      googlePhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Nombre y badges secundarios
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player.displayName,
                                style: TextStyle(
                                    color: c.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5),
                                overflow: TextOverflow.ellipsis),
                            if (player.apodo != null &&
                                player.apodo!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('"${player.apodo}"',
                                  style: const TextStyle(
                                      color: Color(0xFFCCFF00),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              _badge(player.tennisLevel,
                                  const Color(0xFFCCFF00)),
                              _badge('ELO ${player.eloRating}',
                                  c.text38),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Categoría — elemento principal
                  if (playerCategory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (catCtx) {
                      final cc = catColor(playerCategory);
                      return GestureDetector(
                        onTap: () async {
                          // Obtener el club del jugador
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users').doc(widget.uid).get();
                          final clubId = userDoc.data()?['homeClubId']?.toString() ?? '';
                          if (!catCtx.mounted) return;
                          Navigator.push(catCtx, MaterialPageRoute(
                            builder: (_) => _CategoryRankingScreen(
                              category: playerCategory,
                              clubId: clubId,
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: cc.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: cc.withOpacity(0.45),
                                width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.military_tech,
                                  color: cc, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'CATEGORÍA $playerCategory',
                                style: TextStyle(
                                    color: cc,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.people_outline,
                                  color: cc.withOpacity(0.7), size: 14),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 10),

                  // Barra de progreso ELO
                  Row(children: [
                    Text('RANGO ELO',
                        style: TextStyle(
                            color: eloData['color'] as Color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('→ ${eloData['next']} ELO',
                        style: TextStyle(
                            color: c.text24, fontSize: 10)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: eloData['pct'] as double,
                      minHeight: 4,
                      backgroundColor: c.overlay(0.1),
                      valueColor: AlwaysStoppedAnimation(
                          eloData['color'] as Color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Map<String, dynamic> _eloData(int elo) {
    const levels = [
      (label: '1ª CATEGORÍA', min: 1800, max: 2100,
       color: Color(0xFFFFD700)),
      (label: '2ª CATEGORÍA', min: 1600, max: 1800,
       color: Color(0xFFCCFF00)),
      (label: '3ª CATEGORÍA', min: 1400, max: 1600,
       color: Colors.greenAccent),
      (label: '4ª CATEGORÍA', min: 1200, max: 1400,
       color: Colors.blueAccent),
      (label: '5ª CATEGORÍA', min: 1000, max: 1200,
       color: Colors.orangeAccent),
      (label: '6ª CATEGORÍA', min: 0,    max: 1000,
       color: Colors.white54),
    ];

    for (int i = 0; i < levels.length; i++) {
      final l = levels[i];
      if (elo >= l.min) {
        return {
          'label': l.label,
          'color': l.color,
          'next':  i > 0 ? '${levels[i - 1].max}' : '★',
          'pct':   ((elo - l.min) / (l.max - l.min)).clamp(0.0, 1.0),
        };
      }
    }
    return {
      'label': 'ELO',
      'color': Colors.white54,
      'next':  '1000',
      'pct':   (elo / 1000).clamp(0.0, 1.0),
    };
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  // ── DATOS DE JUEGO ────────────────────────────────────────────────────────
  Widget _buildPlayerDetails(Player player) {
    final c = TC.of(context);
    final items = <_DetailItem>[];
    if ((player.manoHabil ?? '').isNotEmpty) {
      items.add(_DetailItem(Icons.front_hand_outlined, 'MANO', player.manoHabil!));
    }
    if ((player.reves ?? '').isNotEmpty) {
      items.add(_DetailItem(Icons.sports_tennis, 'REVÉS', player.reves!));
    }
    if ((player.altura ?? '').isNotEmpty) {
      items.add(_DetailItem(Icons.height, 'ALTURA', '${player.altura} cm'));
    }
    if ((player.peso ?? '').isNotEmpty) {
      items.add(_DetailItem(Icons.monitor_weight_outlined, 'PESO', '${player.peso} kg'));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.overlay(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: const Color(0xFFCCFF00), size: 16),
              const SizedBox(height: 4),
              Text(item.value,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text(item.label,
                  style: TextStyle(
                      color: c.text38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ],
          )).toList(),
        ),
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(Player player) {
    final c = TC.of(context);
    final pp   = _pj - _pg;
    final pct  = _pj > 0 ? (_pg / _pj * 100).round() : 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PlayerStatsScreen(
          uid: widget.uid,
          pj: _pj, pg: _pg, pp: pp, pct: pct, pts: _pts,
          player: player,
        ),
      )),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: c.overlay(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border(0.07)),
        ),
        child: Column(children: [
          // Stats de torneo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('$_pj',  'PARTIDOS',  c.text70),
              _vline(),
              _statCol('$_pg',  'VICTORIAS', Colors.greenAccent),
              _vline(),
              _statCol('$pp',   'DERROTAS',  Colors.redAccent),
              _vline(),
              _statCol('$pct%', 'REND.',     const Color(0xFFCCFF00)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: c.border(0.1), height: 1),
          const SizedBox(height: 14),
          // Coins + puntos
          Row(children: [
            Expanded(child: _coinsStat(player.balance_coins)),
            const SizedBox(width: 12),
            Expanded(child: _pointsStat(_pts)),
          ]),
        ]),
      ),
    ));
  }

  Widget _statCol(String val, String label, Color color) =>
      Column(children: [
        Text(val, style: TextStyle(
            color: color, fontSize: 20,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: TC.of(context).text24, fontSize: 8,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
      ]);

  Widget _vline() => Container(
      width: 1, height: 36,
      color: TC.of(context).border(0.08));

  Widget _coinsStat(int coins) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const _CoinsShopScreen(),
    )),
    child: Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFCCFF00).withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.monetization_on,
          color: Color(0xFFCCFF00), size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(NumberFormat('#,###').format(coins),
            style: const TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 16, fontWeight: FontWeight.bold)),
        Text('COINS', style: TextStyle(
            color: TC.of(context).text24, fontSize: 8,
            fontWeight: FontWeight.bold)),
      ]),
      const Spacer(),
      const Icon(Icons.add_circle_outline,
          color: Color(0xFFCCFF00), size: 14),
    ]),
  ));

  Widget _pointsStat(int pts) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.star, color: Colors.orangeAccent, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(NumberFormat('#,###').format(pts),
            style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 16, fontWeight: FontWeight.bold)),
        Text('PUNTOS', style: TextStyle(
            color: TC.of(context).text24, fontSize: 8,
            fontWeight: FontWeight.bold)),
      ]),
    ]),
  );

  // ── TEMA ──────────────────────────────────────────────────────────────────
  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (ctx, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final c = TC.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('APARIENCIA',
                  style: TextStyle(
                      color: c.text38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.overlay(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: c.border(0.08)),
                ),
                child: Row(children: [
                  _ThemeOption(
                    icon: Icons.dark_mode,
                    label: 'OSCURO',
                    selected: isDark,
                    onTap: ThemeService.instance.setDark,
                  ),
                  _ThemeOption(
                    icon: Icons.light_mode,
                    label: 'CLARO',
                    selected: !isDark,
                    onTap: ThemeService.instance.setLight,
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── HISTORIAL ─────────────────────────────────────────────────────────────
  Widget _buildMatchHistory() {
    final c = TC.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Partidos coordinados ─────────────────────────────────────────
        Row(children: [
          Text('PARTIDOS COORDINADOS',
              style: TextStyle(
                  color: c.text38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ]),
        const SizedBox(height: 12),
        _ScheduledMatchHistory(uid: widget.uid),
        const SizedBox(height: 28),

        // ── Torneos ──────────────────────────────────────────────────────
        Row(children: [
          Text('HISTORIAL DE TORNEOS',
              style: TextStyle(
                  color: c.text38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const Spacer(),
          if (!_statsLoaded)
            const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFFCCFF00))),
        ]),
        const SizedBox(height: 12),

        // Stream en tiempo real de inscripciones del jugador
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('inscriptions')
              .where('uid', isEqualTo: widget.uid)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Error al cargar historial:\n${snap.error}',
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 11),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFCCFF00))));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Builder(builder: (ctx2) {
                final c2 = TC.of(ctx2);
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c2.overlay(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(
                    'Todavía no participaste en ningún torneo.\nInscribite en la pestaña TORNEOS.',
                    style: TextStyle(color: c2.text24, fontSize: 12),
                    textAlign: TextAlign.center,
                  )),
                );
              });
            }
            return Column(
              children: docs.map((inscDoc) {
                final tournamentId =
                    inscDoc.reference.parent.parent!.id;
                return _HistoryCard(tournamentId: tournamentId);
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  void _showEditModal(BuildContext ctx, Player player) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: TC.of(ctx).modal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileEditSheet(uid: widget.uid, player: player),
    );
  }

  void _confirmLogout(Player player) {
    final c = TC.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.modal,
        title: Text('Cerrar sesión',
            style: TextStyle(color: c.text)),
        content: Text('¿Seguro que querés salir?',
            style: TextStyle(color: c.text54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR',
                style: TextStyle(color: c.text38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
            child: const Text('SALIR',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Recibe tournamentId y uid. Carga datos del torneo en tiempo real
// con StreamBuilder interno. Cuando se cancela la inscripción, el
// StreamBuilder padre (sobre collectionGroup) quita la card solo.
// ─────────────────────────────────────────────────────────────────────────────
// HISTORIAL PARTIDOS COORDINADOS
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduledMatchHistory extends StatelessWidget {
  final String uid;
  const _ScheduledMatchHistory({required this.uid});

  @override
  Widget build(BuildContext context) {
    // Dos streams: uno donde el jugador es player1 y otro donde es player2
    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(Future.wait([
        FirebaseFirestore.instance
            .collection('scheduled_matches')
            .where('player1Uid', isEqualTo: uid)
            .limit(20)
            .get(),
        FirebaseFirestore.instance
            .collection('scheduled_matches')
            .where('player2Uid', isEqualTo: uid)
            .limit(20)
            .get(),
      ])),
      builder: (ctx, snap) {
        if (snap.hasError) {
          final c = TC.of(ctx);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.overlay(0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No se pudieron cargar los partidos.',
              style: TextStyle(color: c.text38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFCCFF00)),
            ),
          );
        }
        final allDocs = [
          ...snap.data![0].docs,
          ...snap.data![1].docs,
        ];
        // Dedup by doc ID, sort by scheduledAt desc
        final seen = <String>{};
        final docs = allDocs.where((d) => seen.add(d.id)).toList()
          ..sort((a, b) {
            final ta = (a['scheduledAt'] as Timestamp?)?.toDate();
            final tb = (b['scheduledAt'] as Timestamp?)?.toDate();
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

        if (docs.isEmpty) {
          final c = TC.of(ctx);
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.overlay(0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Sin partidos coordinados aún.',
                style: TextStyle(color: c.text24, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? '';
            final isPlayer1 = data['player1Uid'] == uid;
            final rivalUid = isPlayer1
                ? data['player2Uid']?.toString() ?? ''
                : data['player1Uid']?.toString() ?? '';
            final scheduledAt =
                (data['scheduledAt'] as Timestamp?)?.toDate();
            final courtName =
                data['courtName']?.toString() ?? '';
            final timeSlot = data['timeSlot']?.toString() ?? '';

            Color statusColor;
            String statusLabel;
            switch (status) {
              case 'accepted':
                statusColor = const Color(0xFF00C47A);
                statusLabel = 'CONFIRMADO';
                break;
              case 'cancelled':
                statusColor = Colors.redAccent;
                statusLabel = 'CANCELADO';
                break;
              default:
                statusColor = Colors.orangeAccent;
                statusLabel = 'PENDIENTE';
            }

            final c = TC.of(ctx);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.overlay(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: statusColor.withOpacity(0.15)),
              ),
              child: Row(children: [
                Icon(Icons.sports_tennis,
                    color: statusColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RivalName(uid: rivalUid),
                        const SizedBox(height: 3),
                        if (scheduledAt != null)
                          Text(
                            DateFormat('dd/MM/yyyy')
                                .format(scheduledAt) +
                                (timeSlot.isNotEmpty
                                    ? '  ·  $timeSlot'
                                    : ''),
                            style: TextStyle(
                                color: c.text38, fontSize: 11),
                          ),
                        if (courtName.isNotEmpty)
                          Text(courtName,
                              style: TextStyle(
                                  color: c.text24,
                                  fontSize: 10)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Fetches a rival's display name by UID
class _RivalName extends StatelessWidget {
  final String uid;
  const _RivalName({required this.uid});

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    if (uid.isEmpty) {
      return Text('Rival desconocido',
          style: TextStyle(color: c.text54, fontSize: 13));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(),
      builder: (ctx, snap) {
        final name = snap.hasData && snap.data!.exists
            ? (snap.data!['displayName']?.toString() ?? 'Sin nombre')
            : (snap.connectionState == ConnectionState.waiting
                ? '...'
                : 'Jugador');
        return Text(name,
            style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w600));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORIAL TORNEOS
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final String tournamentId;
  const _HistoryCard({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data?.exists == false) {
          return const SizedBox.shrink();
        }
        final data     = snap.data!.data() as Map<String, dynamic>;
        final name     = data['name']?.toString()     ?? 'Torneo';
        final category = data['category']?.toString() ?? '';
        final status   = data['status']?.toString()   ?? 'setup';
        final players  = data['playerCount']           ?? 16;
        final modality = data['modality']?.toString() ?? '';
        final gender   = data['gender']?.toString() ?? '';

        final c = TC.of(context);
        Color    statusColor;
        String   statusLabel;
        IconData statusIcon;
        switch (normalizeTournamentStatus(status)) {
          case 'en_curso':
            statusColor = Colors.greenAccent;
            statusLabel = 'EN CURSO';
            statusIcon  = Icons.play_circle_outline;
            break;
          case 'terminado':
            statusColor = c.text38;
            statusLabel = 'FINALIZADO';
            statusIcon  = Icons.check_circle_outline;
            break;
          case 'proximamente':
            statusColor = Colors.blueAccent;
            statusLabel = 'PRÓXIMAMENTE';
            statusIcon  = Icons.schedule;
            break;
          default: // 'open'
            statusColor = Colors.orangeAccent;
            statusLabel = 'ABIERTO';
            statusIcon  = Icons.how_to_reg;
        }

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => TournamentDetailScreen(
              tournamentId: tournamentId,
              data: data,
            ),
          )),
          child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.overlay(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon,
                      color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Builder(builder: (bCtx) {
                  final c = TC.of(bCtx);
                  return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                    Text('$category · $players jugadores',
                        style: TextStyle(
                            color: c.text38, fontSize: 10)),
                    if (modality.isNotEmpty || gender.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        if (gender.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: Text(gender, style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        if (modality.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFF00).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.3)),
                            ),
                            child: Text(modality, style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                    ],
                  ],
                );
                })),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel, style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TORNEOS
// ─────────────────────────────────────────────────────────────────────────────
class _TournamentsTab extends StatefulWidget {
  final String uid;
  final String userCategory;
  final String homeClubId;
  const _TournamentsTab(
      {required this.uid, required this.userCategory, required this.homeClubId});

  @override
  State<_TournamentsTab> createState() => _TournamentsTabState();
}

class _TournamentsTabState extends State<_TournamentsTab> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(children: [
              Text('TORNEOS',
                  style: TextStyle(
                      color: c.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const Spacer(),
              if (widget.userCategory.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Text(widget.userCategory,
                      style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
              _liveChip(),
            ]),
          ),
          const SizedBox(height: 14),

          // Filtros
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ['Todos', 'Próximos', 'En curso',
                         'Finalizados'].map((f) {
                final sel = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFCCFF00).withOpacity(0.15)
                          : c.overlay(0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFFCCFF00).withOpacity(0.4)
                              : Colors.transparent),
                    ),
                    child: Text(f, style: TextStyle(
                        color: sel
                            ? const Color(0xFFCCFF00)
                            : c.text38,
                        fontSize: 12,
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.homeClubId.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('tournaments')
                      .where('clubId', isEqualTo: widget.homeClubId)
                      .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFCCFF00)));

                var docs = snap.data!.docs.toList();

                // Aplicar filtro de estado (compatible con valores viejos y nuevos)
                if (_filter != 'Todos') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final s = normalizeTournamentStatus(
                        data['status']?.toString() ?? 'open');
                    switch (_filter) {
                      case 'Próximos':
                        return s == 'proximamente' || s == 'open';
                      case 'En curso':
                        return s == 'en_curso';
                      case 'Finalizados':
                        return s == 'terminado';
                      default:
                        return true;
                    }
                  }).toList();
                }

                // Ordenar: mi categoría primero
                const std = ['1era', '2nda', '3era', '4ta', '5ta', '6ta'];
                if (widget.userCategory.isNotEmpty) {
                  docs.sort((a, b) {
                    final aC = (a.data() as Map)['category']?.toString() ?? '';
                    final bC = (b.data() as Map)['category']?.toString() ?? '';
                    final aMatch = aC == widget.userCategory ? 0 : 1;
                    final bMatch = bC == widget.userCategory ? 0 : 1;
                    return aMatch.compareTo(bMatch);
                  });
                }

                if (docs.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          color: c.text24, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        'No hay torneos ${_filter.toLowerCase()}',
                        style: TextStyle(color: c.text38),
                      ),
                    ],
                  ));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final tCat =
                        data['category']?.toString() ?? '';
                    final canInscribe = !std.contains(tCat) ||
                        widget.userCategory.isEmpty ||
                        widget.userCategory == tCat;
                    return _TournamentCard(
                      data:         data,
                      docId:        docs[i].id,
                      uid:          widget.uid,
                      userCategory: widget.userCategory,
                      canInscribe:  canInscribe,
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _liveChip() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('tournaments')
        .where('status', isEqualTo: 'en_curso')
        .snapshots(),
    builder: (ctx, snap) {
      final count = snap.data?.docs.length ?? 0;
      if (count == 0) return const SizedBox();
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.greenAccent.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count EN VIVO',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ]),
      );
    },
  );
}

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String uid;
  final String userCategory;
  final bool   canInscribe;
  const _TournamentCard({
    required this.data,
    required this.docId,
    required this.uid,
    required this.userCategory,
    required this.canInscribe,
  });

  @override
  Widget build(BuildContext context) {
    final name     = data['name']?.toString()       ?? 'TORNEO';
    final category = data['category']?.toString()   ?? '';
    final players  = data['playerCount']             ?? 16;
    final cost     = (data['costoInscripcion'] ?? 0).toDouble();
    final status   = data['status']?.toString()     ?? 'setup';
    final promoUrl = data['promoUrl']?.toString()   ?? '';
    final sets     = data['setsPerMatch']            ?? 3;

    Color  statusColor;
    String statusLabel;
    switch (normalizeTournamentStatus(status)) {
      case 'en_curso':
        statusColor = Colors.greenAccent;  statusLabel = 'EN CURSO';      break;
      case 'terminado':
        statusColor = Colors.white38;      statusLabel = 'FINALIZADO';    break;
      case 'proximamente':
        statusColor = Colors.blueAccent;   statusLabel = 'PRÓXIMAMENTE';  break;
      default: // 'open'
        statusColor = Colors.orangeAccent; statusLabel = 'ABIERTO';
    }

    final isMyCat = canInscribe &&
        data['category']?.toString().isNotEmpty == true;

    final c = TC.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(
              tournamentId: docId, data: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isMyCat
              ? catColor(category).withOpacity(0.05)
              : c.overlay(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMyCat
                ? catColor(category).withOpacity(0.30)
                : statusColor.withOpacity(0.15),
            width: isMyCat ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Imagen
          if (promoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              child: Image.network(promoUrl,
                  height: 130, width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Center(child: Icon(
                  Icons.emoji_events,
                  color: statusColor.withOpacity(0.4),
                  size: 36)),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Expanded(child: Text(name,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel, style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (category.isNotEmpty)
                  _chip(
                    category,
                    canInscribe
                        ? catColor(category)
                        : Colors.white38,
                  ),
                _chip('Al mejor de $sets sets', Colors.white38),
                if (cost > 0)
                  _chip('\$${NumberFormat('#,###').format(cost)}',
                      const Color(0xFFCCFF00))
                else
                  _chip('GRATIS', Colors.greenAccent),
                _SpotsChip(
                    tournamentId: docId,
                    playerCount: players is int ? players : 16),
              ]),
              // Badge bloqueada / inscripto + botón — reactivo
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tournaments')
                    .doc(docId)
                    .collection('inscriptions')
                    .doc(uid)
                    .snapshots(),
                builder: (ctx, inscSnap) {
                  final isInscribed =
                      inscSnap.data?.exists == true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge estado inscripción / categoría bloqueada
                      if (isInscribed && status == 'setup') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.25)),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.greenAccent, size: 11),
                            SizedBox(width: 5),
                            Text('INSCRIPTO',
                                style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ] else if (!canInscribe && status == 'setup') ...[
                        const SizedBox(height: 8),
                        Builder(builder: (bCtx) {
                          final bc = TC.of(bCtx);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: bc.overlay(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(Icons.lock_outline,
                                  color: bc.text24, size: 11),
                              const SizedBox(width: 5),
                              Text('Solo para $category',
                                  style: TextStyle(
                                      color: bc.text38,
                                      fontSize: 10)),
                            ]),
                          );
                        }),
                      ],

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInscribed
                                ? Colors.greenAccent.withOpacity(0.15)
                                : status == 'done'
                                    ? c.overlay(0.05)
                                    : status == 'active'
                                        ? c.overlay(0.1)
                                        : canInscribe
                                            ? const Color(0xFFCCFF00)
                                            : c.overlay(0.06),
                            foregroundColor: isInscribed
                                ? Colors.greenAccent
                                : (status == 'setup' && canInscribe)
                                    ? Colors.black
                                    : Colors.white54,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: isInscribed
                                ? BorderSide(
                                    color: Colors.greenAccent
                                        .withOpacity(0.35))
                                : BorderSide.none,
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => TournamentDetailScreen(
                                      tournamentId: docId, data: data))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isInscribed) ...[
                                const Icon(Icons.check_circle,
                                    size: 14),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                isInscribed
                                    ? 'YA INSCRIPTO · VER'
                                    : status == 'done'
                                        ? 'VER RESULTADOS'
                                        : status == 'active'
                                            ? 'VER FIXTURE'
                                            : canInscribe
                                                ? 'INSCRIBIRME'
                                                : 'VER TORNEO',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10,
        fontWeight: FontWeight.bold)),
  );

}

// ─────────────────────────────────────────────────────────────────────────────
// SPOTS CHIP — muestra lugares disponibles en tiempo real
// ─────────────────────────────────────────────────────────────────────────────
class _SpotsChip extends StatelessWidget {
  final String tournamentId;
  final int playerCount;

  const _SpotsChip(
      {required this.tournamentId, required this.playerCount});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('inscriptions')
          .snapshots(),
      builder: (_, snap) {
        final inscribed = snap.data?.docs.length ?? 0;
        final remaining =
            (playerCount - inscribed).clamp(0, playerCount);
        final Color color = remaining == 0
            ? Colors.redAccent
            : remaining <= 3
                ? Colors.orangeAccent
                : Colors.white38;
        final label = remaining == 0
            ? 'COMPLETO'
            : '$remaining lugares';
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String   label;
  final String   value;
  const _DetailItem(this.icon, this.label, this.value);
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB CANCHAS — reserva de canchas del club del jugador
// ─────────────────────────────────────────────────────────────────────────────
class _CourtsTab extends StatefulWidget {
  final String uid;
  const _CourtsTab({required this.uid});
  @override
  State<_CourtsTab> createState() => _CourtsTabState();
}

class _CourtsTabState extends State<_CourtsTab> {
  int _subTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = PlayerHomeScreen.pendingCourtsSubTab;
      if (pending != null && mounted) {
        setState(() => _subTab = pending);
        PlayerHomeScreen.pendingCourtsSubTab = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(widget.uid).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
        }
        final data         = snap.data!.data() as Map<String, dynamic>? ?? {};
        final homeClubId   = data['homeClubId']?.toString()   ?? '';
        final homeClubName = data['homeClubName']?.toString() ?? 'Mi Club';

        if (homeClubId.isEmpty) return const _NoClubView();

        return Column(children: [
          // Sub-tab bar
          Container(
            color: const Color(0xFF060F0C),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _subTabItem(0, 'RESERVAR'),
              _subTabItem(1, 'MIS RESERVAS'),
            ]),
          ),
          Expanded(child: IndexedStack(
            index: _subTab,
            children: [
              ReservaPickerScreen(clubId: homeClubId, clubName: homeClubName),
              _MisReservasTab(uid: widget.uid),
            ],
          )),
        ]);
      },
    );
  }

  Widget _subTabItem(int i, String label) {
    final sel = _subTab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subTab = i),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: sel ? const Color(0xFFCCFF00) : Colors.transparent,
              width: 2,
            )),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? const Color(0xFFCCFF00) : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.5,
            )),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Badge de conteo real de reservas activas ─────────────────────────────────
class _ReservasCountBadge extends StatefulWidget {
  final String uid;
  const _ReservasCountBadge({required this.uid});
  @override
  State<_ReservasCountBadge> createState() => _ReservasCountBadgeState();
}

class _ReservasCountBadgeState extends State<_ReservasCountBadge> {
  int _count = 0;
  StreamSubscription<QuerySnapshot>? _sub1;
  StreamSubscription<QuerySnapshot>? _sub2;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    void update(_) {
      // Re-query ambas snapshots y recalcular
      Future.wait([
        db.collection('scheduled_matches')
            .where('player1Uid', isEqualTo: widget.uid)
            .get(),
        db.collection('scheduled_matches')
            .where('player2Uid', isEqualTo: widget.uid)
            .get(),
      ]).then((results) {
        final docs = {...results[0].docs, ...results[1].docs};
        final count = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? '';
          if (status == 'cancelled' || status == 'cancelado') return false;
          final ts = data['scheduledAt'] as Timestamp?;
          if (ts == null) return true;
          return ts.toDate().isAfter(now.subtract(const Duration(hours: 1)));
        }).length;
        if (mounted) setState(() => _count = count);
      });
    }
    _sub1 = db.collection('scheduled_matches')
        .where('player1Uid', isEqualTo: widget.uid)
        .snapshots().listen(update);
    _sub2 = db.collection('scheduled_matches')
        .where('player2Uid', isEqualTo: widget.uid)
        .snapshots().listen(update);
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$_count',
          style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 11)),
    );
  }
}

// MIS RESERVAS — historial de reservas y partidos agendados del jugador
// Consulta directamente de: courts/reservations (por jugador) + scheduled_matches
// ─────────────────────────────────────────────────────────────────────────────
class _MisReservasTab extends StatefulWidget {
  final String uid;
  const _MisReservasTab({required this.uid});

  @override
  State<_MisReservasTab> createState() => _MisReservasTabState();
}

class _MisReservasTabState extends State<_MisReservasTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _showCancelled = false;
  StreamSubscription<QuerySnapshot>? _sub1;
  StreamSubscription<QuerySnapshot>? _sub2;
  final List<StreamSubscription<QuerySnapshot>> _courtSubs = [];

  @override
  void initState() {
    super.initState();
    _startListeners();
  }

  Future<void> _startListeners() async {
    final db = FirebaseFirestore.instance;

    // Escuchar partidos coordinados (como jugador 1 o 2)
    _sub1 = db.collection('scheduled_matches')
        .where('player1Uid', isEqualTo: widget.uid)
        .snapshots()
        .listen((_) => _reload());
    _sub2 = db.collection('scheduled_matches')
        .where('player2Uid', isEqualTo: widget.uid)
        .snapshots()
        .listen((_) => _reload());

    // Escuchar reservas de canchas — una query por cancha (sin índice collectionGroup)
    try {
      final userSnap = await db.collection('users').doc(widget.uid).get();
      final homeClubId = userSnap.data()?['homeClubId']?.toString() ?? '';
      if (homeClubId.isNotEmpty) {
        final courts = await db
            .collection('clubs').doc(homeClubId)
            .collection('courts')
            .get();
        for (final court in courts.docs) {
          final sub = db
              .collection('clubs').doc(homeClubId)
              .collection('courts').doc(court.id)
              .collection('reservations')
              .where('playerId', isEqualTo: widget.uid)
              .snapshots()
              .listen((_) => _reload());
          _courtSubs.add(sub);
        }
      }
    } catch (_) {}

    _reload();
  }

  Future<void> _reload() async {
    final data = await _loadAll();
    if (mounted) setState(() { _items = data; _loading = false; });
  }

  // Los registros cancelados se conservan en Firestore para estadísticas.
  // "Limpiar" solo oculta la sección en pantalla.
  void _clearCancelled() {
    if (mounted) setState(() => _showCancelled = false);
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    for (final s in _courtSubs) s.cancel();
    super.dispose();
  }

  // ── ELIMINAR RESERVA DE CANCHA ─────────────────────────────────────────────
  Future<void> _cancelBooking(Map<String, dynamic> doc) async {
    final groupId  = doc['bookingGroupId']?.toString() ?? '';
    final courtId  = doc['courtId']?.toString()        ?? '';
    final clubId   = doc['clubId']?.toString()         ?? '';
    final dateVal  = doc['date']?.toString()           ?? '';
    final payment  = doc['paymentMethod']?.toString()  ?? '';
    final total    = (doc['totalPrice'] ?? 0).toDouble();

    final db = FirebaseFirestore.instance;

    if (courtId.isNotEmpty && clubId.isNotEmpty) {
      QuerySnapshot snap;
      if (groupId.isNotEmpty && !groupId.startsWith('legacy_')) {
        // Reserva con bookingGroupId real → borrar por grupo
        snap = await db
            .collection('clubs').doc(clubId)
            .collection('courts').doc(courtId)
            .collection('reservations')
            .where('bookingGroupId', isEqualTo: groupId)
            .get();
      } else {
        // Reserva legacy (sin bookingGroupId) → borrar por fecha + jugador
        snap = await db
            .collection('clubs').doc(clubId)
            .collection('courts').doc(courtId)
            .collection('reservations')
            .where('playerId', isEqualTo: widget.uid)
            .where('date', isEqualTo: dateVal)
            .get();
      }
      final batch = db.batch();
      for (final s in snap.docs) batch.delete(s.reference);
      await batch.commit();
    }

    // Devolver coins si corresponde
    if (payment == 'coins' && total > 0) {
      await db.collection('users').doc(widget.uid)
          .update({'balance_coins': FieldValue.increment(total.toInt())});
      await db.collection('users').doc(widget.uid)
          .collection('coin_transactions').add({
        'amount':      total.toInt(),
        'type':        'booking_refund',
        'description': 'Reintegro reserva ${doc["courtName"]} · ${doc["date"]}',
        'createdAt':   FieldValue.serverTimestamp(),
        'date':        DateTime.now().toIso8601String(),
      });
    }
    // _reload() será llamado automáticamente por el StreamSubscription
  }

  // ── CANCELAR PARTIDO COORDINADO ────────────────────────────────────────────
  Future<void> _cancelMatch(Map<String, dynamic> doc) async {
    final matchId     = doc['matchDocId']?.toString()  ?? '';
    final opponentUid = doc['opponentUid']?.toString() ?? '';
    final date        = doc['date']?.toString()        ?? '';
    final timeSlot    = doc['timeSlot']?.toString()
        ?? doc['startTime']?.toString()                ?? '';

    final db      = FirebaseFirestore.instance;
    final myName  = FirebaseAuth.instance.currentUser?.displayName ?? 'Tu rival';

    if (matchId.isNotEmpty) {
      // Marcar partido como cancelado
      await db.collection('scheduled_matches').doc(matchId)
          .update({'status': 'cancelled',
                   'cancelledAt': FieldValue.serverTimestamp()});

      // Liberar turnos de cancha reservados para este partido
      try {
        final userSnap = await db.collection('users').doc(widget.uid).get();
        final clubId = userSnap.data()?['homeClubId']?.toString() ?? '';
        if (clubId.isNotEmpty) {
          final courts = await db.collection('clubs').doc(clubId)
              .collection('courts').get();
          for (final court in courts.docs) {
            final resSnap = await db
                .collection('clubs').doc(clubId)
                .collection('courts').doc(court.id)
                .collection('reservations')
                .where('matchId', isEqualTo: matchId)
                .get();
            if (resSnap.docs.isNotEmpty) {
              final batch = db.batch();
              for (final s in resSnap.docs) batch.delete(s.reference);
              await batch.commit();
            }
          }
        }
      } catch (_) {}
    }

    if (opponentUid.isNotEmpty) {
      await PushNotificationService.notifyMatchCancelled(
        toUid:    opponentUid,
        fromName: myName,
        date:     date,
        timeSlot: timeSlot,
      );
    }
    // _reload() será llamado automáticamente por el StreamSubscription
  }

  // ── DIALOG DE DETALLES ────────────────────────────────────────────────────
  void _showDetails(BuildContext context, Map<String, dynamic> doc) {
    final isMatch     = doc['type'] == 'match';
    final status      = doc['status']?.toString() ?? '';
    final isCancelled = status == 'cancelled' || status == 'cancelado';
    final dateStr     = doc['date']?.toString()        ?? '';
    final startTime   = doc['startTime']?.toString()   ?? '';
    final endTime     = doc['endTime']?.toString()     ?? '';
    final payment     = doc['paymentMethod']?.toString() ?? '';
    final total       = (doc['totalPrice'] ?? 0).toDouble();
    final opponent    = doc['opponentName']?.toString() ?? '';
    final court       = doc['courtName']?.toString()   ?? '';
    final club        = doc['clubName']?.toString()    ?? '';

    String dateLabel = dateStr;
    try {
      final p = dateStr.split('-');
      if (p.length == 3) dateLabel = '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: TC.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isMatch
                          ? 'Partido vs $opponent'
                          : (court.isNotEmpty ? court : 'Reserva de cancha'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.white38, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detalles
              _detailRow(Icons.calendar_today, dateLabel),
              if (startTime.isNotEmpty)
                _detailRow(Icons.schedule,
                    '$startTime${endTime.isNotEmpty ? ' – $endTime' : ''}'),
              if (club.isNotEmpty)
                _detailRow(Icons.stadium_outlined, club),
              if (!isMatch && total > 0)
                _detailRow(
                  Icons.payments_outlined,
                  payment == 'coins'
                      ? '${total.toInt()} coins'
                      : '\$${NumberFormat('#,###', 'es').format(total.toInt())}',
                ),
              _detailRow(Icons.info_outline, _statusLabel(status)),

              const SizedBox(height: 24),

              // Botón cancelar (solo si no está ya cancelado)
              if (!isCancelled)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      isMatch ? 'CANCELAR PARTIDO' : 'CANCELAR RESERVA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: Text(isMatch
                              ? 'Cancelar partido'
                              : 'Cancelar reserva'),
                          content: Text(isMatch
                              ? 'Se notificará a $opponent. ¿Confirmás?'
                              : payment == 'coins'
                                  ? 'Se cancelará la reserva y se te devolverán ${total.toInt()} coins.'
                                  : 'Se cancelará la reserva. ¿Confirmás?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('NO')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('CANCELAR'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      if (isMatch) {
                        await _cancelMatch(doc);
                      } else {
                        await _cancelBooking(doc);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isMatch
                              ? '✅ Partido cancelado. Se notificó a $opponent.'
                              : payment == 'coins'
                                  ? '✅ Reserva cancelada. Coins devueltos.'
                                  : '✅ Reserva cancelada.'),
                          backgroundColor: const Color(0xFF1A4D32),
                        ));
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 15),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 13))),
    ]),
  );

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmado':  return 'Confirmado';
      case 'pendiente':   return 'Pendiente de confirmación';
      case 'cancelado':   return 'Cancelado';
      case 'cancelled':   return 'Cancelado';
      case 'scheduled':   return 'Agendado';
      default:            return s;
    }
  }

  Future<List<Map<String, dynamic>>> _loadAll() async {
    final db  = FirebaseFirestore.instance;
    final all = <Map<String, dynamic>>[];
    final seenGroups = <String>{};

    // ── 1. Leer homeClubId del usuario ──────────────────────────────────────
    final userSnap   = await db.collection('users').doc(widget.uid).get();
    final userData   = userSnap.data() ?? {};
    final homeClubId   = userData['homeClubId']?.toString()   ?? '';
    final homeClubName = userData['homeClubName']?.toString() ?? '';

    // ── 2. Reservas de canchas (fuente de verdad) ────────────────────────────
    if (homeClubId.isNotEmpty) {
      try {
        final courts = await db
            .collection('clubs').doc(homeClubId)
            .collection('courts')
            .get();

        for (final court in courts.docs) {
          final courtName = (court.data()['courtName'] ?? '').toString();

          final resSnap = await db
              .collection('clubs').doc(homeClubId)
              .collection('courts').doc(court.id)
              .collection('reservations')
              .where('playerId', isEqualTo: widget.uid)
              .get();

          // Agrupar todos los slots por bookingGroupId para calcular precio total
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final res in resSnap.docs) {
            final d = res.data();
            final rawGroup = d['bookingGroupId']?.toString() ?? '';
            final groupId = rawGroup.isNotEmpty
                ? rawGroup
                : 'legacy_${court.id}_${d["date"]}';
            groups.putIfAbsent(groupId, () => []).add(d);
          }

          for (final entry in groups.entries) {
            final groupId = entry.key;
            if (!seenGroups.add(groupId)) continue;

            final slots    = entry.value;
            final first    = slots.first;
            final dateStr  = first['date']?.toString()       ?? '';
            final startStr = first['startRange']?.toString() ?? first['time']?.toString() ?? '';
            final endStr   = first['endRange']?.toString()   ?? '';
            // Suma de todos los slots del grupo
            final totalPrice = slots.fold(0.0,
                (sum, s) => sum + ((s['amount'] ?? 0) as num).toDouble());

            DateTime? dt;
            try {
              if (dateStr.isNotEmpty && startStr.isNotEmpty) {
                final parts  = dateStr.split('-');
                final tParts = startStr.split(':');
                dt = DateTime(
                  int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
                  int.parse(tParts[0]), int.parse(tParts[1]),
                );
              }
            } catch (_) {}

            all.add({
              'type':           'booking',
              'clubId':         homeClubId,
              'clubName':       homeClubName,
              'courtId':        court.id,
              'courtName':      courtName,
              'date':           dateStr,
              'startTime':      startStr,
              'endTime':        endStr,
              'totalPrice':     totalPrice,
              'status':         first['status']        ?? '',
              'paymentMethod':  first['paymentMethod'] ?? '',
              'bookingGroupId': groupId,
              'scheduledAt':    dt != null ? Timestamp.fromDate(dt) : null,
            });
          }
        }
      } catch (_) {}
    }

    // ── 3. Partidos coordinados como jugador 1 ──────────────────────────────
    try {
      final snap1 = await db.collection('scheduled_matches')
          .where('player1Uid', isEqualTo: widget.uid)
          .get();
      for (final doc in snap1.docs) {
        final d = doc.data();
        all.add(_matchEntry(doc.id, d, isPlayer1: true));
      }
    } catch (_) {}

    // ── 4. Partidos coordinados como jugador 2 ──────────────────────────────
    try {
      final snap2 = await db.collection('scheduled_matches')
          .where('player2Uid', isEqualTo: widget.uid)
          .get();
      for (final doc in snap2.docs) {
        final d = doc.data();
        all.add(_matchEntry(doc.id, d, isPlayer1: false));
      }
    } catch (_) {}

    // ── Ordenar por fecha ───────────────────────────────────────────────────
    all.sort((a, b) {
      final ta = a['scheduledAt'] as Timestamp?;
      final tb = b['scheduledAt'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.toDate().compareTo(tb.toDate());
    });

    return all;
  }

  Map<String, dynamic> _matchEntry(
      String docId, Map<String, dynamic> d, {required bool isPlayer1}) {
    final opponent = isPlayer1
        ? (d['player2Name'] ?? '').toString()
        : (d['player1Name'] ?? '').toString();

    final ts         = d['scheduledAt'] as Timestamp?;
    final dt         = ts?.toDate();
    final dateStr    = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : '';
    final timeStr    = dt != null ? DateFormat('HH:mm').format(dt) : '';

    final opponentUid = isPlayer1
        ? (d['player2Uid'] ?? '').toString()
        : (d['player1Uid'] ?? '').toString();

    return {
      'type':         'match',
      'matchDocId':   docId,
      'opponentName': opponent,
      'opponentUid':  opponentUid,
      'courtName':    d['courtName']  ?? '',
      'clubName':     d['clubName']   ?? '',
      'date':         dateStr,
      'startTime':    timeStr,
      'timeSlot':     d['timeSlot']   ?? timeStr,
      'endTime':      '',
      'totalPrice':   0,
      'status':       d['status']     ?? 'scheduled',
      'scheduledAt':  ts,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))),
      );
    }

    final now = DateTime.now();
    // Excluir canceladas/cancelados
    final active = _items.where((d) {
      final s = d['status']?.toString() ?? '';
      return s != 'cancelled' && s != 'cancelado';
    }).toList();

    final upcoming = active.where((d) {
      final ts = d['scheduledAt'] as Timestamp?;
      if (ts == null) return true;
      return ts.toDate().isAfter(now.subtract(const Duration(hours: 1)));
    }).toList();

    final past = active.where((d) {
      final ts = d['scheduledAt'] as Timestamp?;
      if (ts == null) return false;
      return ts.toDate().isBefore(now.subtract(const Duration(hours: 1)));
    }).toList().reversed.toList();

    final cancelled = _items.where((d) {
      final s = d['status']?.toString() ?? '';
      return s == 'cancelled' || s == 'cancelado';
    }).toList();

    final c = TC.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header con ícono de historial
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
              child: Row(children: [
                Text('MIS RESERVAS',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const Spacer(),
                // Ícono historial: muestra/oculta canceladas
                if (cancelled.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _showCancelled = !_showCancelled),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _showCancelled
                            ? c.overlay(0.1)
                            : c.overlay(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _showCancelled
                                ? c.border(0.24)
                                : c.border(0.12)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history_rounded,
                            color: _showCancelled
                                ? c.text70 : c.text38,
                            size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'HISTORIAL',
                          style: TextStyle(
                            color: _showCancelled
                                ? c.text70 : c.text38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
          color: const Color(0xFFCCFF00),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          onRefresh: () => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              if (active.isEmpty && cancelled.isEmpty)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_outlined,
                          color: c.overlay(0.07),
                          size: 72),
                      const SizedBox(height: 16),
                      Text('Sin reservas todavía',
                          style: TextStyle(color: c.text38, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('Reservá una cancha o coordiná un partido',
                          style: TextStyle(color: c.text24, fontSize: 12)),
                    ],
                  ),
                ),
              if (upcoming.isNotEmpty) ...[
                _sectionLabel('PRÓXIMAS'),
                ...upcoming.map((d) => _ReservaCard(
                    doc: d,
                    onTap: () => _showDetails(context, d))),
                const SizedBox(height: 16),
              ],
              if (past.isNotEmpty) ...[
                _sectionLabel('HISTORIAL'),
                ...past.take(20).map((d) => _ReservaCard(
                    doc: d, isPast: true,
                    onTap: () => _showDetails(context, d))),
                const SizedBox(height: 16),
              ],
              // ── Canceladas (colapsables) ──────────────────────────────────
              if (cancelled.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _showCancelled = !_showCancelled),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(children: [
                      Text(
                        'CANCELADAS (${cancelled.length})',
                        style: TextStyle(
                          color: c.text24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _showCancelled
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: c.text24, size: 16,
                      ),
                      const Spacer(),
                      if (_showCancelled)
                        GestureDetector(
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('Ocultar canceladas'),
                                content: const Text('Se ocultarán los registros cancelados. Los datos quedan guardados para estadísticas. Podés volver a verlos tocando HISTORIAL.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('NO')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('LIMPIAR')),
                                ],
                              ),
                            );
                            if (ok == true) _clearCancelled();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: const Text('LIMPIAR',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ),
                        ),
                    ]),
                  ),
                ),
                if (_showCancelled)
                  ...cancelled.map((d) => _ReservaCard(
                      doc: d, isPast: true,
                      onTap: () => _showDetails(context, d))),
              ],
            ],
          ),
        ),
            ),  // Expanded
          ],
        ),  // Column
      ),  // SafeArea
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(label,
      style: TextStyle(
        color: TC.of(context).text38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      )),
  );
}

class _ReservaCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool isPast;
  final VoidCallback? onTap;
  const _ReservaCard({required this.doc, this.isPast = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final type         = doc['type']?.toString() ?? 'booking';
    final isMatch      = type == 'match';
    final courtName    = doc['courtName']?.toString() ?? '';
    final clubName     = doc['clubName']?.toString() ?? '';
    final date         = doc['date']?.toString() ?? '';
    final startTime    = doc['startTime']?.toString() ?? doc['timeSlot']?.toString() ?? '';
    final endTime      = doc['endTime']?.toString() ?? '';
    final opponent     = doc['opponentName']?.toString() ?? '';
    final totalPrice   = (doc['totalPrice'] ?? 0).toDouble();
    final status       = doc['status']?.toString() ?? 'pendiente';
    final payment      = doc['paymentMethod']?.toString() ?? '';

    // Format date
    String dateLabel = date;
    try {
      if (date.isNotEmpty) {
        final parts = date.split('-');
        if (parts.length == 3) {
          dateLabel = '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
    } catch (_) {}

    final accent = isMatch ? const Color(0xFF5B9CF6) : const Color(0xFFCCFF00);

    final c = TC.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.overlay(isPast ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPast
              ? c.border(0.06)
              : accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isMatch ? Icons.sports_tennis : Icons.calendar_month,
            color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMatch
                  ? 'Partido vs ${opponent.isNotEmpty ? opponent : "Rival"}'
                  : (courtName.isNotEmpty ? courtName : 'Cancha'),
              style: TextStyle(
                color: isPast ? c.text38 : c.text,
                fontWeight: FontWeight.bold,
                fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              '$dateLabel${startTime.isNotEmpty ? '  $startTime' : ''}${endTime.isNotEmpty ? '–$endTime' : ''}',
              style: TextStyle(color: c.text38, fontSize: 11),
            ),
            if (clubName.isNotEmpty)
              Text(clubName,
                  style: TextStyle(color: c.text24, fontSize: 10)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_statusLabel(status),
              style: TextStyle(
                color: _statusColor(status),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
          ),
          if (!isMatch && totalPrice > 0) ...[
            const SizedBox(height: 4),
            Text(
              payment == 'coins'
                  ? '${totalPrice.toInt()} 🪙'
                  : '\$${NumberFormat('#,###', 'es').format(totalPrice.toInt())}',
              style: TextStyle(
                color: c.text38, fontSize: 10)),
          ],
          // Indicador de tappable
          if (onTap != null)
            Icon(Icons.chevron_right, color: c.text12, size: 16),
        ]),
      ]),
    )); // GestureDetector + Container
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmado': return Colors.greenAccent;
      case 'pendiente':  return Colors.orangeAccent;
      case 'cancelado':
      case 'cancelled':  return Colors.redAccent;
      case 'scheduled':  return const Color(0xFF5B9CF6);
      default:           return Colors.white38;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmado': return 'CONFIRMADO';
      case 'pendiente':  return 'PENDIENTE';
      case 'cancelado':
      case 'cancelled':  return 'CANCELADO';
      case 'scheduled':  return 'AGENDADO';
      default:           return s.toUpperCase();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA SIN CLUB — pide al jugador que seleccione su club en el perfil
// ─────────────────────────────────────────────────────────────────────────────
class _NoClubView extends StatelessWidget {
  const _NoClubView();

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFF00).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stadium_outlined,
                      color: Color(0xFFCCFF00), size: 48),
                ),
                const SizedBox(height: 24),
                Text('SIN CLUB ASIGNADO',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
                Text(
                  'Seleccioná tu club en tu perfil para ver la disponibilidad de canchas y hacer reservas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.text38, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // El usuario debe ir al tab 0 (perfil) y editar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Andá a tu PERFIL → tocá el ícono de editar → seleccioná tu club'),
                        backgroundColor: Color(0xFF1A3A34),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline,
                      color: Colors.black, size: 18),
                  label: const Text('IR A MI PERFIL',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TIENDA — lista de clubes con tiendas
// ─────────────────────────────────────────────────────────────────────────────
class _StoreTab extends StatelessWidget {
  final String uid;
  const _StoreTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator(
                color: Color(0xFFCCFF00))),
          );
        }
        final data        = snap.data!.data() as Map<String, dynamic>? ?? {};
        final homeClubId  = data['homeClubId']?.toString()  ?? '';
        final homeClubName = data['homeClubName']?.toString() ?? 'Mi Club';

        if (homeClubId.isEmpty) return const _NoClubView();

        // Ir directamente a la tienda del club del jugador
        return ClubStoreScreen(
          clubId:   homeClubId,
          clubName: homeClubName,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER DEL HERO — cancha de tenis abstracta
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// PROFILE EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileEditSheet extends StatefulWidget {
  final String uid;
  final Player player;
  const _ProfileEditSheet({required this.uid, required this.player});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  static const _levels = ['Principiante', 'Intermedio', 'Avanzado'];
  static const _cats   = ['1era', '2nda', '3era', '4ta', '5ta', '6ta'];

  late final TextEditingController _nicknameCtrl;
  late String _level;
  late String _category;
  String? _localPhotoPath; // foto recién tomada (antes de subir)
  bool   _uploadingPhoto = false;
  bool   _saving         = false;

  // Datos adicionales del jugador
  String _manoHabil  = 'Diestro';
  String _reves      = 'Dos manos';
  late TextEditingController _alturaCtrl;
  late TextEditingController _pesoCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _domicilioCtrl;

  // Club del jugador
  String? _selectedClubId;
  String? _selectedClubName;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(
        text: widget.player.apodo ?? '');
    _level    = widget.player.tennisLevel;
    _category = widget.player.category ?? '';
    _alturaCtrl   = TextEditingController();
    _pesoCtrl     = TextEditingController();
    _dniCtrl      = TextEditingController();
    _domicilioCtrl = TextEditingController();
    // Cargar club actual del usuario
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get()
        .then((doc) {
      if (mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _selectedClubId    = data['homeClubId']?.toString();
          _selectedClubName  = data['homeClubName']?.toString();
          _manoHabil         = data['manoHabil']?.toString()  ?? 'Diestro';
          _reves             = data['reves']?.toString()      ?? 'Dos manos';
          _alturaCtrl.text   = data['altura']?.toString()     ?? '';
          _pesoCtrl.text     = data['peso']?.toString()       ?? '';
          _dniCtrl.text      = data['dni']?.toString()        ?? '';
          _domicilioCtrl.text = data['domicilio']?.toString() ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _alturaCtrl.dispose();
    _pesoCtrl.dispose();
    _dniCtrl.dispose();
    _domicilioCtrl.dispose();
    super.dispose();
  }

  // ── FOTO CON CÁMARA ────────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    // Guía previa
    final goAhead = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.of(context).modal,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Silueta guía
          Container(
            width: 120, height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFCCFF00).withOpacity(0.4),
                  width: 1.5),
            ),
            child: Stack(alignment: Alignment.center, children: [
              // Óvalo cabeza
              Container(
                width: 64, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                      color: const Color(0xFFCCFF00), width: 2),
                ),
              ),
              // Hombros
              Positioned(
                bottom: 10,
                child: Container(
                  width: 90, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(50)),
                    border: Border.all(
                        color: const Color(0xFFCCFF00), width: 2),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('PARA UNA BUENA FOTO',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          _tip(Icons.wb_sunny_outlined,
              'Luz natural frontal, no contraluz'),
          _tip(Icons.person_outline,
              'Cara centrada, mirando a cámara'),
          _tip(Icons.crop_free,
              'Fondo neutro o pared lisa'),
          _tip(Icons.do_not_disturb_on_outlined,
              'Sin lentes de sol ni gorra'),
          const SizedBox(height: 4),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ABRIR CÁMARA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (goAhead != true || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Recorte circular con image_cropper
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'RECORTÁ TU FOTO',
          toolbarColor: const Color(0xFF0B2218),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFCCFF00),
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Recortá tu foto',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _localPhotoPath = cropped.path;
      _uploadingPhoto = true;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref('user_photos/${widget.uid}.jpg');
      await ref.putFile(File(cropped.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'photoUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: const Color(0xFFCCFF00), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(
              color: Colors.white54, fontSize: 12))),
    ]),
  );

  // ── SELECCIONAR CLUB ───────────────────────────────────────────────────────
  Future<void> _pickClub() async {
    final clubs = await FirebaseFirestore.instance
        .collection('clubs')
        .get();
    if (!mounted) return;

    if (clubs.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clubes registrados.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: TC.of(context).modal,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('SELECCIONÁ TU CLUB',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
          const Divider(color: Colors.white12),
          ...clubs.docs.map((doc) {
            final d    = doc.data();
            final name = d['name']?.toString() ?? 'Club';
            final addr = d['address']?.toString() ?? '';
            final sel  = _selectedClubId == doc.id;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFFCCFF00).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.stadium_outlined,
                    color: sel
                        ? const Color(0xFFCCFF00)
                        : Colors.white38,
                    size: 20),
              ),
              title: Text(name,
                  style: TextStyle(
                      color: sel ? const Color(0xFFCCFF00) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              subtitle: addr.isNotEmpty
                  ? Text(addr,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11))
                  : null,
              trailing: sel
                  ? const Icon(Icons.check_circle,
                      color: Color(0xFFCCFF00), size: 18)
                  : null,
              onTap: () {
                setState(() {
                  _selectedClubId   = doc.id;
                  _selectedClubName = name;
                });
                Navigator.pop(ctx);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── GUARDAR ────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
        'apodo':         _nicknameCtrl.text.trim(),
        'tennisLevel':   _level,
        'category':      _category,
        'manoHabil':     _manoHabil,
        'reves':         _reves,
        if (_alturaCtrl.text.trim().isNotEmpty)
          'altura':      _alturaCtrl.text.trim(),
        if (_pesoCtrl.text.trim().isNotEmpty)
          'peso':        _pesoCtrl.text.trim(),
        if (_dniCtrl.text.trim().isNotEmpty)
          'dni':         _dniCtrl.text.trim(),
        if (_domicilioCtrl.text.trim().isNotEmpty)
          'domicilio':   _domicilioCtrl.text.trim(),
        if (_selectedClubId != null) 'homeClubId':   _selectedClubId,
        if (_selectedClubId != null) 'homeClubName': _selectedClubName ?? '',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final googleName = FirebaseAuth.instance.currentUser?.displayName
        ?? widget.player.displayName;
    final currentPhoto = _localPhotoPath != null
        ? FileImage(File(_localPhotoPath!)) as ImageProvider
        : (widget.player.photoUrl?.isNotEmpty == true
            ? NetworkImage(widget.player.photoUrl!) as ImageProvider
            : null);

    return Padding(
      // Mueve el sheet sobre el teclado
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D2218),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Contenido scrolleable
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  const Text('EDITAR PERFIL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 24),

                  // ── FOTO ─────────────────────────────────────────────
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFCCFF00),
                                width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor:
                                const Color(0xFF1A3A34),
                            backgroundImage: currentPhoto,
                            child: currentPhoto == null
                                ? const Icon(Icons.person,
                                    size: 52,
                                    color: Colors.white24)
                                : null,
                          ),
                        ),
                        if (_uploadingPhoto)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28, height: 28,
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFCCFF00),
                                      strokeWidth: 2.5),
                                ),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap:
                              _uploadingPhoto ? null : _takePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFF00),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFCCFF00)
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Tocá el ícono para sacar una foto',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── NOMBRE DE GOOGLE (fijo) ───────────────────────────
                  _label('NOMBRE (GOOGLE)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.white24, size: 15),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(googleName,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El nombre de Google no se puede modificar.',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 20),

                  // ── APODO ─────────────────────────────────────────────
                  _label('APODO (OPCIONAL)'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _nicknameCtrl,
                    hint: 'Ej: El Rayo, Topo...',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Se mostrará junto a tu nombre en la app.',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 20),

                  // ── NIVEL ─────────────────────────────────────────────
                  _label('NIVEL DE TENIS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _levels.map((l) {
                      final sel = l == _level;
                      return _selectChip(
                        label: l,
                        selected: sel,
                        onTap: () => setState(() => _level = l),
                        activeColor: const Color(0xFFCCFF00),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── CATEGORÍA ─────────────────────────────────────────
                  _label('CATEGORÍA'),
                  const SizedBox(height: 4),
                  const Text(
                    'Podés ajustarla; el coordinador puede cambiarla.',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _cats.map((c) {
                      final sel = c == _category;
                      return _selectChip(
                        label: c,
                        selected: sel,
                        onTap: () =>
                            setState(() => _category = c),
                        activeColor: catColor(c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── MANO HÁBIL ────────────────────────────────────────
                  _label('MANO HÁBIL'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Diestro', 'Zurdo', 'Ambidiestro'].map((m) {
                      final sel = m == _manoHabil;
                      return _selectChip(
                        label: m,
                        selected: sel,
                        onTap: () => setState(() => _manoHabil = m),
                        activeColor: const Color(0xFFCCFF00),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── REVÉS ─────────────────────────────────────────────
                  _label('REVÉS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Una mano', 'Dos manos'].map((r) {
                      final sel = r == _reves;
                      return _selectChip(
                        label: r,
                        selected: sel,
                        onTap: () => setState(() => _reves = r),
                        activeColor: const Color(0xFFCCFF00),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── MEDIDAS ───────────────────────────────────────────
                  _label('MEDIDAS'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _textField(
                        controller: _alturaCtrl,
                        hint: 'Altura (cm)',
                        keyboardType: TextInputType.number,
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _textField(
                        controller: _pesoCtrl,
                        hint: 'Peso (kg)',
                        keyboardType: TextInputType.number,
                      ),
                    ])),
                  ]),
                  const SizedBox(height: 20),

                  // ── DNI Y DOMICILIO ───────────────────────────────────
                  _label('DNI'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _dniCtrl,
                    hint: 'Número de documento',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _label('DOMICILIO'),
                  const SizedBox(height: 4),
                  const Text(
                    'Para envíos de la tienda y premios.',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _domicilioCtrl,
                    hint: 'Calle, número, ciudad',
                  ),
                  const SizedBox(height: 20),

                  // ── MI CLUB ───────────────────────────────────────────
                  _label('MI CLUB'),
                  const SizedBox(height: 4),
                  const Text(
                    'Verás canchas, jugadores y tienda de tu club.',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _pickClub(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedClubId != null
                            ? const Color(0xFFCCFF00).withOpacity(0.07)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedClubId != null
                              ? const Color(0xFFCCFF00).withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.stadium_outlined,
                            color: _selectedClubId != null
                                ? const Color(0xFFCCFF00)
                                : Colors.white38,
                            size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedClubName?.isNotEmpty == true
                                ? _selectedClubName!
                                : 'Seleccioná tu club',
                            style: TextStyle(
                              color: _selectedClubId != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down,
                            color: Colors.white38, size: 20),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── GUARDAR ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        minimumSize:
                            const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                      onPressed: (_saving || _uploadingPhoto)
                          ? null
                          : _save,
                      child: (_saving || _uploadingPhoto)
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5))
                          : const Text('GUARDAR',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFCCFF00), width: 1.5)),
        ),
      );

  Widget _selectChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color activeColor,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? activeColor
                : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? activeColor
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.black : Colors.white54,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13)),
        ),
      );
}

class _HeroPainter extends CustomPainter {
  final bool isDark;
  const _HeroPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = isDark ? const Color(0xFF0D2A22) : const Color(0xFF1A4A34),
    );

    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Rectángulo exterior de cancha
    final margin = w * 0.05;
    canvas.drawRect(
        Rect.fromLTRB(margin, h * 0.08, w - margin, h * 0.92), p);

    // Línea central (net)
    canvas.drawLine(
        Offset(margin, h * 0.5), Offset(w - margin, h * 0.5), p);

    // Línea central vertical
    canvas.drawLine(
        Offset(w / 2, h * 0.08), Offset(w / 2, h * 0.92),
        p..color = Colors.white.withValues(alpha: 0.04));

    // Cuadros de servicio
    p.color = Colors.white.withValues(alpha: 0.08);
    final si = w * 0.18;
    canvas.drawLine(Offset(margin + si, h * 0.08),
        Offset(margin + si, h * 0.5), p);
    canvas.drawLine(Offset(w - margin - si, h * 0.08),
        Offset(w - margin - si, h * 0.5), p);
    canvas.drawLine(Offset(margin + si, h * 0.5),
        Offset(w - margin - si, h * 0.5 + (h * 0.42) * 0.45), p);

    // Línea de servicio horizontal superior
    canvas.drawLine(
        Offset(margin + si, h * 0.08 + (h * 0.42) * 0.45),
        Offset(w - margin - si, h * 0.08 + (h * 0.42) * 0.45), p);

    // Acento verde lima sutil en la net
    canvas.drawLine(
      Offset(margin - 4, h * 0.5),
      Offset(w - margin + 4, h * 0.5),
      Paint()
        ..color = const Color(0xFFCCFF00).withOpacity(0.08)
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER STATS SCREEN — estadísticas detalladas del jugador
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerStatsScreen extends StatelessWidget {
  final String uid;
  final int    pj;
  final int    pg;
  final int    pp;
  final int    pct;
  final int    pts;
  final Player player;

  const _PlayerStatsScreen({
    required this.uid,
    required this.pj,
    required this.pg,
    required this.pp,
    required this.pct,
    required this.pts,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('MIS ESTADÍSTICAS',
            style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Resumen general
          _sectionTitle('RENDIMIENTO GENERAL'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statCard('$pj',   'PARTIDOS',  c.text70)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('$pg',   'VICTORIAS', Colors.greenAccent)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('$pp',   'DERROTAS',  Colors.redAccent)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _statCard('$pct%', 'RENDIMIENTO', const Color(0xFFCCFF00))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('${player.eloRating}', 'ELO', Colors.blueAccent)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('$pts',  'PTS RANKING', Colors.orangeAccent)),
          ]),
          const SizedBox(height: 24),

          // Perfil de juego
          _sectionTitle('PERFIL DE JUEGO'),
          const SizedBox(height: 12),
          _profileRow(Icons.sports_tennis, 'Nivel', player.tennisLevel),
          _profileRow(Icons.military_tech, 'Categoría', player.category ?? '–'),
          _profileRow(Icons.back_hand_outlined, 'Mano hábil', player.preferredHand),
          const SizedBox(height: 24),

          // ELO info
          _sectionTitle('RANKING ELO'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.overlay(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border(0.07)),
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ELO ACTUAL',
                      style: TextStyle(
                          color: c.text38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  Text('${player.eloRating}',
                      style: TextStyle(
                          color: c.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El ELO sube con victorias y baja con derrotas. '
                'El sistema tiene en cuenta la diferencia de nivel entre jugadores.',
                style: TextStyle(
                    color: c.text38, fontSize: 11, height: 1.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Builder(builder: (ctx) => Text(
    title,
    style: TextStyle(
        color: TC.of(ctx).text38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5),
  ));

  Widget _statCard(String value, String label, Color color) => Builder(
    builder: (ctx) {
      final c = TC.of(ctx);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.text38,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8)),
        ]),
      );
    },
  );

  Widget _profileRow(IconData icon, String label, String value) => Builder(
    builder: (ctx) {
      final c = TC.of(ctx);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.overlay(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFFCCFF00), size: 16),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: c.text38, fontSize: 12)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COINS SHOP SCREEN — comprar coins (MP pendiente)
// ─────────────────────────────────────────────────────────────────────────────
class _CoinsShopScreen extends StatelessWidget {
  const _CoinsShopScreen();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('COMPRAR COINS',
            style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid).snapshots(),
        builder: (ctx, snap) {
          final coins = snap.hasData
              ? ((snap.data!.data() as Map?)?['balance_coins'] ?? 0) as int
              : 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Saldo actual
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFCCFF00).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.monetization_on,
                      color: Color(0xFFCCFF00), size: 32),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      NumberFormat('#,###').format(coins),
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                    const Text('TU SALDO ACTUAL',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),

              Text('PAQUETES DE COINS',
                  style: TextStyle(
                      color: c.text38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),

              ...[
                (base: 5000,   bonus: 500,   pct: '10%'),
                (base: 10000,  bonus: 1500,  pct: '15%'),
                (base: 20000,  bonus: 4000,  pct: '20%'),
                (base: 50000,  bonus: 12500, pct: '25%'),
                (base: 100000, bonus: 30000, pct: '30%'),
              ].map((pkg) => _CoinPackage(
                baseCoins: pkg.base,
                bonusCoins: pkg.bonus,
                bonusPct:  pkg.pct,
                uid:       uid,
              )),

              const SizedBox(height: 24),

              // ── Historial de transacciones ──────────────────────────
              Text('HISTORIAL',
                  style: TextStyle(
                      color: c.text38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(uid)
                    .collection('coin_transactions')
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (ctx, txSnap) {
                  if (!txSnap.hasData || txSnap.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Sin transacciones todavía.',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    );
                  }
                  return Column(
                    children: txSnap.data!.docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final amount = (d['amount'] ?? 0) as int;
                      final desc   = d['description']?.toString() ?? '';
                      final date   = d['date']?.toString() ?? '';
                      String dateLabel = '';
                      try {
                        if (date.isNotEmpty) {
                          final dt = DateTime.parse(date);
                          dateLabel = DateFormat('dd/MM/yy HH:mm').format(dt);
                        }
                      } catch (_) {}
                      final isPositive = amount >= 0;
                      return Builder(builder: (bCtx) {
                        final bc = TC.of(bCtx);
                        return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bc.overlay(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: bc.border(0.07)),
                        ),
                        child: Row(children: [
                          Icon(
                            isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isPositive ? const Color(0xFFCCFF00) : Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(desc,
                                    style: TextStyle(
                                        color: bc.text70, fontSize: 11)),
                                if (dateLabel.isNotEmpty)
                                  Text(dateLabel,
                                      style: TextStyle(
                                          color: bc.text38, fontSize: 9)),
                              ],
                            ),
                          ),
                          Text(
                            '${isPositive ? '+' : ''}$amount',
                            style: TextStyle(
                                color: isPositive
                                    ? const Color(0xFFCCFF00)
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ]),
                      );
                      }); // Builder
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.overlay(0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border(0.07)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: c.text24, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Período de prueba: coins gratis. '
                      'Próximamente: pago con MercadoPago. '
                      'Usá coins para reservar canchas, inscribirte a torneos y comprar en la tienda.',
                      style: TextStyle(
                          color: c.text38, fontSize: 11, height: 1.5),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CoinPackage extends StatelessWidget {
  final int    baseCoins;  // coins que paga el usuario
  final int    bonusCoins; // coins extra de regalo
  final String bonusPct;   // e.g. '10%'
  final String uid;

  const _CoinPackage({
    required this.baseCoins,
    required this.bonusCoins,
    required this.bonusPct,
    required this.uid,
  });

  int get _total => baseCoins + bonusCoins;

  Future<void> _buy(BuildContext context) async {
    final fmt = NumberFormat('#,###');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F1A),
        title: Text(
          '${fmt.format(baseCoins)} + ${fmt.format(bonusCoins)} COINS',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on,
                color: Color(0xFFCCFF00), size: 48),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  TextSpan(text: 'Recibís ${fmt.format(baseCoins)} coins'),
                  TextSpan(
                    text: ' + ${fmt.format(bonusCoins)} de bonus ($bonusPct)',
                    style: const TextStyle(
                        color: Color(0xFFCCFF00), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '\nTotal: ${fmt.format(_total)} coins'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'GRATIS durante el período de prueba',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCCFF00)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.black,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true) return;

    final now = DateTime.now();
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .update({'balance_coins': FieldValue.increment(_total)});
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('coin_transactions').add({
        'amount':      _total,
        'baseCoins':   baseCoins,
        'bonusCoins':  bonusCoins,
        'bonusPct':    bonusPct,
        'type':        'purchase_free',
        'description': 'Compra: ${NumberFormat('#,###').format(baseCoins)} coins + ${NumberFormat('#,###').format(bonusCoins)} bonus ($bonusPct)',
        'createdAt':   FieldValue.serverTimestamp(),
        'date':        now.toIso8601String(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${NumberFormat('#,###').format(_total)} coins acreditados (${NumberFormat('#,###').format(baseCoins)} + ${NumberFormat('#,###').format(bonusCoins)} bonus)'),
          backgroundColor: const Color(0xFF1A4D32),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return GestureDetector(
      onTap: () => _buy(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFCCFF00).withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          const Icon(Icons.monetization_on,
              color: Color(0xFFCCFF00), size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${fmt.format(baseCoins)} COINS',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '  +${fmt.format(bonusCoins)}',
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                'BONUS $bonusPct GRATIS',
                style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFCCFF00).withValues(alpha: 0.3)),
            ),
            child: Text(
              bonusPct,
              style: const TextStyle(
                  color: Color(0xFFCCFF00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY RANKING SCREEN — listado de jugadores de una categoría en el club
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryRankingScreen extends StatelessWidget {
  final String category;
  final String clubId;

  const _CategoryRankingScreen({
    required this.category,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    final cc = catColor(category);
    final c = TC.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CATEGORÍA $category',
                style: TextStyle(
                    color: cc,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1)),
            const Text('JUGADORES DEL CLUB',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: clubId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('users')
                .where('category', isEqualTo: category)
                .where('homeClubId', isEqualTo: clubId)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('users')
                .where('category', isEqualTo: category)
                .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00)));
          }
          final players = snap.data!.docs;
          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      color: cc.withOpacity(0.3), size: 64),
                  const SizedBox(height: 16),
                  Text('Sin jugadores en $category',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 14)),
                ],
              ),
            );
          }

          // Ordenar por ELO descendente
          final sorted = List<DocumentSnapshot>.from(players)
            ..sort((a, b) {
              final eloA = ((a.data() as Map)['eloRating'] ?? 1000) as num;
              final eloB = ((b.data() as Map)['eloRating'] ?? 1000) as num;
              return eloB.compareTo(eloA);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final data  = sorted[i].data() as Map<String, dynamic>;
              final name  = data['displayName']?.toString() ?? 'Jugador';
              final apodo = data['apodo']?.toString() ?? '';
              final elo   = (data['eloRating'] ?? 1000) as int;
              final level = data['tennisLevel']?.toString() ?? '';
              final photo = data['photoUrl']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: i == 0
                      ? cc.withOpacity(0.08)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == 0
                        ? cc.withOpacity(0.3)
                        : Colors.white.withOpacity(0.07),
                  ),
                ),
                child: Row(children: [
                  // Posición
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                          color: i == 0 ? cc : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF1A3A34),
                    backgroundImage:
                        photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      if (apodo.isNotEmpty)
                        Text('"$apodo"',
                            style: const TextStyle(
                                color: Color(0xFFCCFF00),
                                fontSize: 10,
                                fontStyle: FontStyle.italic)),
                      Text(level,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ],
                  )),
                  // ELO
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$elo',
                          style: TextStyle(
                              color: cc,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      const Text('ELO',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME OPTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = TC.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFCCFF00).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: const Color(0xFFCCFF00).withOpacity(0.4),
                    width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFFCCFF00)
                    : c.text38,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFCCFF00)
                      : c.text38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
