import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tournament_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'club_dashboard_screen.dart';
import 'register_club_screen.dart';
import 'tournament_management_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORES DE MARCA
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0A1F1A);
const _kCard    = Color(0xFF1A3A34);
const _kLime    = Color(0xFFCCFF00);
const _kBorder  = Color(0x14FFFFFF);

Color _statusColor(String s) {
  switch (normalizeTournamentStatus(s)) {
    case 'en_curso':     return Colors.greenAccent;
    case 'terminado':    return Colors.white38;
    case 'proximamente': return Colors.blueAccent;
    default:             return Colors.orangeAccent; // 'open'
  }
}

String _statusLabel(String s) {
  switch (normalizeTournamentStatus(s)) {
    case 'en_curso':     return 'EN CURSO';
    case 'terminado':    return 'FINALIZADO';
    case 'proximamente': return 'PRÓXIMAMENTE';
    default:             return 'ABIERTO';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _goToMyClub() async {
    final clubData = await DatabaseService().getClubByOwner(_uid);
    if (!mounted) return;
    if (clubData != null) {
      final clubId = clubData['id']?.toString() ?? '';
      if (clubId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ClubDashboardScreen(clubId: clubId)));
        return;
      }
    }
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => const RegisterClubScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PANEL ADMIN',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5)),
          Text(FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: _goToMyClub,
            icon: const Icon(Icons.sports_tennis, color: _kLime, size: 15),
            label: const Text('MI CLUB',
                style: TextStyle(
                    color: _kLime, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
            onPressed: () async => await AuthService().signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _kLime,
          indicatorWeight: 2,
          labelColor: _kLime,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'RESUMEN'),
            Tab(text: 'CLUBES'),
            Tab(text: 'TORNEOS'),
            Tab(text: 'USUARIOS'),
            Tab(text: 'FINANZAS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ResumenTab(),
          _ClubesTab(),
          _TorneosTab(),
          _UsuariosTab(),
          _FinanzasTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB RESUMEN
// ─────────────────────────────────────────────────────────────────────────────
class _ResumenTab extends StatelessWidget {
  const _ResumenTab();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kLime,
      backgroundColor: _kCard,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _sectionLabel('PLATAFORMA'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'CLUBES',
              icon: Icons.stadium,
              color: Colors.blueAccent,
              stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'TORNEOS',
              icon: Icons.emoji_events,
              color: Colors.orangeAccent,
              stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'JUGADORES',
              icon: Icons.groups,
              color: _kLime,
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'player')
                  .snapshots(),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'EN CURSO',
              icon: Icons.play_circle_outline,
              color: Colors.greenAccent,
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .where('status', isEqualTo: 'en_curso')
                  .snapshots(),
            )),
          ]),
          const SizedBox(height: 12),
          // Coins en circulación
          _CoinsCirculationCard(),
          const SizedBox(height: 28),
          _sectionLabel('ACTIVIDAD RECIENTE'),
          const SizedBox(height: 12),
          _RecentActivity(),
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 2));

class _CoinsCirculationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'player')
          .snapshots(),
      builder: (ctx, snap) {
        int total = 0;
        int players = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            total += ((d['balance_coins'] ?? 0) as num).toInt();
            players++;
          }
        }
        final avg = players > 0 ? (total / players).round() : 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kLime.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kLime.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.monetization_on, color: _kLime, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(NumberFormat('#,###').format(total),
                    style: const TextStyle(
                        color: _kLime,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const Text('COINS EN CIRCULACIÓN',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(NumberFormat('#,###').format(avg),
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const Text('PROMEDIO/\nJUGADOR',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.white24, fontSize: 8)),
            ]),
          ]),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (ctx, snap) {
      final count = snap.data?.docs.length ?? 0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ]),
      );
    },
  );
}

class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _kLime, strokeWidth: 2));
        }
        if (snap.hasError) {
          // El índice puede no existir aún — fallback sin orderBy
          return _RecentActivityFallback();
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
                child: Text('Sin actividad reciente',
                    style: TextStyle(color: Colors.white24))),
          );
        }
        return Column(
          children: docs.map((doc) => _activityRow(doc)).toList(),
        );
      },
    );
  }
}

class _RecentActivityFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('notifications')
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = [...(snap.data?.docs ?? [])]
          ..sort((a, b) {
            final tA = (a.data() as Map)['createdAt'];
            final tB = (b.data() as Map)['createdAt'];
            if (tA is Timestamp && tB is Timestamp) {
              return tB.compareTo(tA);
            }
            final kA = (a.data() as Map)['sortKey']?.toString() ?? '';
            final kB = (b.data() as Map)['sortKey']?.toString() ?? '';
            return kB.compareTo(kA);
          });
        return Column(
          children: docs.map((doc) => _activityRow(doc)).toList(),
        );
      },
    );
  }
}

Widget _activityRow(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final msg  = data['message']?.toString() ?? '';
  final ts   = data['createdAt'];
  String timeStr = data['date']?.toString() ?? '';
  if (ts is Timestamp) {
    timeStr = DateFormat('dd/MM HH:mm').format(ts.toDate());
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Expanded(child: Text(msg,
          style: const TextStyle(color: Colors.white60, fontSize: 11))),
      const SizedBox(width: 8),
      Text(timeStr,
          style: const TextStyle(color: Colors.white24, fontSize: 9)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB CLUBES
// ─────────────────────────────────────────────────────────────────────────────
class _ClubesTab extends StatelessWidget {
  const _ClubesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _kLime));
        }

        final clubs = snap.data!.docs;
        if (clubs.isEmpty) {
          return const Center(child: Text('Sin clubes registrados',
              style: TextStyle(color: Colors.white38)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          itemCount: clubs.length,
          itemBuilder: (ctx, i) {
            final data    = clubs[i].data() as Map<String, dynamic>;
            final id      = clubs[i].id;
            final name    = data['name']?.toString()    ?? 'Club sin nombre';
            final addr    = data['address']?.toString() ?? '';
            final courts  = data['courtCount']          ?? 0;
            final ownerId = data['ownerId']?.toString() ?? '';

            return GestureDetector(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => ClubDashboardScreen(clubId: id))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stadium,
                            color: Colors.blueAccent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          if (addr.isNotEmpty)
                            Text(addr,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                        ],
                      )),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$courts canchas',
                            style: const TextStyle(
                                color: _kLime,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.chevron_right,
                            color: Colors.white24, size: 16),
                      ]),
                    ]),
                    if (ownerId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      _ClubStats(clubId: id),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClubStats extends StatelessWidget {
  final String clubId;
  const _ClubStats({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .where('clubId', isEqualTo: clubId)
          .snapshots(),
      builder: (ctx, snap) {
        final tournaments = snap.data?.docs ?? [];
        final total    = tournaments.length;
        final enCurso  = tournaments.where((d) {
          final s = normalizeTournamentStatus(
              (d.data() as Map)['status']?.toString() ?? '');
          return s == 'en_curso';
        }).length;
        return Row(children: [
          _miniStat('$total', 'TORNEOS', Colors.orangeAccent),
          const SizedBox(width: 16),
          _miniStat('$enCurso', 'EN CURSO', Colors.greenAccent),
        ]);
      },
    );
  }

  Widget _miniStat(String val, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(val, style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
          color: Colors.white24, fontSize: 9)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TORNEOS
// ─────────────────────────────────────────────────────────────────────────────
class _TorneosTab extends StatefulWidget {
  const _TorneosTab();

  @override
  State<_TorneosTab> createState() => _TorneosTabState();
}

class _TorneosTabState extends State<_TorneosTab> {
  String _filter = 'todos';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filtro de estado
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Todos',        'todos',        Colors.white54),
            _chip('Abiertos',     'open',         Colors.orangeAccent),
            _chip('En curso',     'en_curso',     Colors.greenAccent),
            _chip('Próximamente', 'proximamente', Colors.blueAccent),
            _chip('Finalizados',  'terminado',    Colors.white38),
          ]),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: _kLime));
            }

            var docs = snap.data!.docs;
            if (_filter != 'todos') {
              docs = docs.where((d) {
                final s = normalizeTournamentStatus(
                    (d.data() as Map)['status']?.toString() ?? '');
                return s == _filter;
              }).toList();
            }

            if (docs.isEmpty) {
              return const Center(child: Text('Sin torneos',
                  style: TextStyle(color: Colors.white38)));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data     = docs[i].data() as Map<String, dynamic>;
                final id       = docs[i].id;
                final name     = data['name']?.toString()     ?? 'Torneo';
                final category = data['category']?.toString() ?? '';
                final clubId   = data['clubId']?.toString()   ?? '';
                final players  = data['playerCount']          ?? 16;
                final status   = data['status']?.toString()   ?? 'open';
                final sc       = _statusColor(status);
                final sl       = _statusLabel(status);
                final cost     = (data['costoInscripcion'] ?? 0).toDouble();
                final modality = data['modality']?.toString() ?? '';
                final gender   = data['gender']?.toString()   ?? '';

                return GestureDetector(
                  onTap: clubId.isNotEmpty ? () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => TournamentManagementScreen(
                        clubId:         clubId,
                        tournamentId:   id,
                        tournamentName: name,
                        playerCount:    players,
                      ))) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sc.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(sl,
                                style: TextStyle(
                                    color: sc,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          if (category.isNotEmpty) ...[
                            Text(category,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10)),
                            const Text(' · ',
                                style: TextStyle(color: Colors.white12)),
                          ],
                          Text('Capacidad: $players',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                          const Spacer(),
                        ]),
                        if (modality.isNotEmpty || gender.isNotEmpty) ...[
                          const SizedBox(height: 6),
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
                                child: Text(modality, style: const TextStyle(color: _kLime, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ]),
                        ],
                        const SizedBox(height: 8),
                        // Contador de inscriptos real + acciones de estado
                        Row(children: [
                          _InscriptosCount(tournamentId: id, capacity: players),
                          const Spacer(),
                          if (cost > 0)
                            Text(
                              '\$${NumberFormat('#,###').format(cost)}',
                              style: const TextStyle(
                                  color: _kLime,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(width: 10),
                          // Cambiar estado
                          _TournamentStatusMenu(
                              tournamentId: id,
                              currentStatus: normalizeTournamentStatus(status)),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _chip(String label, String value, Color color) => GestureDetector(
    onTap: () => setState(() => _filter = value),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _filter == value
            ? color.withOpacity(0.15)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _filter == value
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08)),
      ),
      child: Text(label,
          style: TextStyle(
              color: _filter == value ? color : Colors.white38,
              fontSize: 11,
              fontWeight: _filter == value
                  ? FontWeight.bold
                  : FontWeight.normal)),
    ),
  );
}

class _InscriptosCount extends StatelessWidget {
  final String tournamentId;
  final int capacity;
  const _InscriptosCount({
    required this.tournamentId,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('inscriptions')
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        final color = count >= capacity
            ? Colors.redAccent
            : count > 0
                ? Colors.greenAccent
                : Colors.white24;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person, color: color, size: 12),
          const SizedBox(width: 4),
          Text('$count / $capacity inscriptos',
              style: TextStyle(
                  color: color, fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]);
      },
    );
  }
}

class _TournamentStatusMenu extends StatelessWidget {
  final String tournamentId;
  final String currentStatus;
  const _TournamentStatusMenu({
    required this.tournamentId,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF1A3A34),
      icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        _statusItem('proximamente', 'PRÓXIMAMENTE', Colors.blueAccent),
        _statusItem('open',         'ABIERTO',      Colors.orangeAccent),
        _statusItem('en_curso',     'EN CURSO',     Colors.greenAccent),
        _statusItem('terminado',    'FINALIZADO',   Colors.white38),
      ],
      onSelected: (newStatus) async {
        await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournamentId)
            .update({'status': newStatus});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Estado → ${_statusLabel(newStatus)}'),
            backgroundColor: _statusColor(newStatus).withOpacity(0.8),
          ));
        }
      },
    );
  }

  PopupMenuItem<String> _statusItem(String value, String label, Color color) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: value == currentStatus ? _kLime : Colors.white70,
                  fontSize: 12,
                  fontWeight: value == currentStatus
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB USUARIOS
// ─────────────────────────────────────────────────────────────────────────────
class _UsuariosTab extends StatefulWidget {
  const _UsuariosTab();

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  String _roleFilter = 'all';
  String _search     = '';
  final _searchCtrl  = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('users');
    if (_roleFilter != 'all') {
      query = query.where('role', isEqualTo: _roleFilter);
    }

    return Column(children: [
      // Barra de búsqueda
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o email…',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: const Icon(Icons.search,
                color: Colors.white38, size: 18),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 16))
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Filtro por rol
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _roleChip('Todos',         'all',         Colors.white54),
            _roleChip('Jugadores',     'player',      _kLime),
            _roleChip('Coordinadores', 'coordinator', Colors.purpleAccent),
            _roleChip('Coaches',       'coach',       Colors.blueAccent),
            _roleChip('Admins',        'admin',       Colors.redAccent),
          ]),
        ),
      ),
      const SizedBox(height: 8),

      // Lista
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: query.limit(150).snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: _kLime));
            }

            var users = snap.data!.docs;

            // Filtro de búsqueda client-side
            if (_search.isNotEmpty) {
              users = users.where((d) {
                final data  = d.data() as Map<String, dynamic>;
                final name  = data['displayName']?.toString().toLowerCase() ?? '';
                final email = data['email']?.toString().toLowerCase() ?? '';
                return name.contains(_search) || email.contains(_search);
              }).toList();
            }

            if (users.isEmpty) {
              return const Center(child: Text('Sin usuarios',
                  style: TextStyle(color: Colors.white38)));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: users.length,
              itemBuilder: (ctx, i) {
                final data  = users[i].data() as Map<String, dynamic>;
                final uid   = users[i].id;
                final name  = data['displayName']?.toString() ?? 'Sin nombre';
                final email = data['email']?.toString()       ?? '';
                final role  = data['role']?.toString()        ?? 'pending';
                // Usar photoUrl (foto de app) — fallback a photoURL (Google)
                final photo = data['photoUrl']?.toString().isNotEmpty == true
                    ? data['photoUrl'].toString()
                    : data['photoURL']?.toString() ?? '';
                final coins    = ((data['balance_coins'] ?? 0) as num).toInt();
                final cat      = data['category']?.toString()    ?? '';
                final level    = data['tennisLevel']?.toString() ?? '';
                final curUid   = FirebaseAuth.instance.currentUser?.uid ?? '';

                final rColor = _roleColor(role);

                return GestureDetector(
                  onTap: () => _showUserModal(ctx, uid, name, email,
                      role, coins, cat, level, photo, curUid),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: rColor.withOpacity(0.15),
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo) : null,
                        child: photo.isEmpty
                            ? Text(name.isNotEmpty
                                ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    color: rColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text(email,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                          if (cat.isNotEmpty || level.isNotEmpty)
                            Text(
                              [if (cat.isNotEmpty) cat,
                               if (level.isNotEmpty) level].join(' · '),
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 9),
                            ),
                        ],
                      )),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(role.toUpperCase(),
                              style: TextStyle(
                                  color: rColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat('#,###').format(coins),
                          style: const TextStyle(
                              color: _kLime, fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('coins',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 8)),
                      ]),
                      const SizedBox(width: 4),
                      const Icon(Icons.more_vert,
                          color: Colors.white24, size: 16),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':       return Colors.redAccent;
      case 'coordinator': return Colors.purpleAccent;
      case 'coach':       return Colors.blueAccent;
      case 'player':      return _kLime;
      default:            return Colors.white24;
    }
  }

  Widget _roleChip(String label, String value, Color color) => GestureDetector(
    onTap: () => setState(() => _roleFilter = value),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _roleFilter == value
            ? color.withOpacity(0.15)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _roleFilter == value
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08)),
      ),
      child: Text(label,
          style: TextStyle(
              color: _roleFilter == value ? color : Colors.white38,
              fontSize: 11,
              fontWeight: _roleFilter == value
                  ? FontWeight.bold
                  : FontWeight.normal)),
    ),
  );

  void _showUserModal(
    BuildContext ctx,
    String uid,
    String name,
    String email,
    String currentRole,
    int coins,
    String category,
    String level,
    String photo,
    String currentUid,
  ) {
    final isSelf = uid == currentUid;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0D1F1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Cabecera usuario
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _roleColor(currentRole).withOpacity(0.2),
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: _roleColor(currentRole),
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(email,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                if (category.isNotEmpty || level.isNotEmpty)
                  Text([if (category.isNotEmpty) category,
                         if (level.isNotEmpty) level].join(' · '),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(NumberFormat('#,###').format(coins),
                  style: const TextStyle(
                      color: _kLime, fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Text('coins',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 20),

          // Cambiar rol
          if (!isSelf) ...[
            _sheetLabel('CAMBIAR ROL'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in ['player', 'coordinator', 'coach', 'admin'])
                GestureDetector(
                  onTap: () async {
                    if (r == 'admin') {
                      final ok = await showDialog<bool>(
                        context: sheetCtx,
                        builder: (dlgCtx) => AlertDialog(
                          backgroundColor: const Color(0xFF0D1220),
                          title: const Text('Confirmar',
                              style: TextStyle(color: Colors.white)),
                          content: Text(
                            '¿Asignar rol ADMIN a $name?\nEsta acción le da acceso completo.',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dlgCtx, false),
                              child: const Text('CANCELAR',
                                  style: TextStyle(color: Colors.white38)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(dlgCtx, true),
                              child: const Text('CONFIRMAR',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                    }
                    // Para coordinador, también asignar a un club
                    if (r == 'coordinator') {
                      final clubs = await FirebaseFirestore.instance
                          .collection('clubs').get();
                      if (clubs.docs.isEmpty) {
                        await FirebaseFirestore.instance
                            .collection('users').doc(uid)
                            .update({'role': r});
                      } else {
                        String? selectedClubId;
                        if (sheetCtx.mounted) {
                          selectedClubId = await showDialog<String>(
                            context: sheetCtx,
                            builder: (dlgCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF0D1220),
                              title: const Text('Asignar club al coordinador',
                                  style: TextStyle(color: Colors.white, fontSize: 15)),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: clubs.docs.map((c) {
                                    final cName = (c.data()['name'] ?? 'Club').toString();
                                    return ListTile(
                                      title: Text(cName,
                                          style: const TextStyle(color: Colors.white)),
                                      onTap: () => Navigator.pop(dlgCtx, c.id),
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dlgCtx, null),
                                  child: const Text('CANCELAR',
                                      style: TextStyle(color: Colors.white38)),
                                ),
                              ],
                            ),
                          );
                        }
                        final updates = <String, dynamic>{'role': r};
                        if (selectedClubId != null) {
                          updates['admin_club_id'] = selectedClubId;
                        }
                        await FirebaseFirestore.instance
                            .collection('users').doc(uid)
                            .update(updates);
                      }
                    } else {
                      await FirebaseFirestore.instance
                          .collection('users').doc(uid)
                          .update({'role': r});
                    }
                    if (sheetCtx.mounted) {
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                        content: Text('$name → $r'),
                        backgroundColor: const Color(0xFF1A4D32),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: r == currentRole
                          ? _kLime.withOpacity(0.15)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: r == currentRole
                              ? _kLime.withOpacity(0.4)
                              : Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(r.toUpperCase(),
                        style: TextStyle(
                            color: r == currentRole ? _kLime : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const SizedBox(height: 20),
          ],

          // Gestión de coins
          _sheetLabel('GESTIONAR COINS'),
          const SizedBox(height: 10),
          _CoinsManager(uid: uid, name: name, currentCoins: coins),
        ]),
      ),
    );
  }
}

Widget _sheetLabel(String text) => Text(text,
    style: const TextStyle(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5));

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET GESTIÓN DE COINS — sumar / restar / establecer valor exacto
// ─────────────────────────────────────────────────────────────────────────────
class _CoinsManager extends StatefulWidget {
  final String uid;
  final String name;
  final int    currentCoins;
  const _CoinsManager({
    required this.uid,
    required this.name,
    required this.currentCoins,
  });

  @override
  State<_CoinsManager> createState() => _CoinsManagerState();
}

class _CoinsManagerState extends State<_CoinsManager> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  // 'add', 'subtract', 'set'
  String _mode = 'add';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _modeBtn('add',      '+',    Colors.greenAccent),
        const SizedBox(width: 8),
        _modeBtn('subtract', '−',    Colors.redAccent),
        const SizedBox(width: 8),
        _modeBtn('set',      '= SET', Colors.orangeAccent),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _mode == 'set'
                  ? 'Valor exacto (actual: ${widget.currentCoins})'
                  : 'Cantidad de coins',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kLime,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: _saving ? null : _apply,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Text('OK',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold)),
        ),
      ]),
    ]);
  }

  Widget _modeBtn(String mode, String label, Color color) => GestureDetector(
    onTap: () => setState(() => _mode = mode),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _mode == mode
            ? color.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _mode == mode
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08)),
      ),
      child: Text(label,
          style: TextStyle(
              color: _mode == mode ? color : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ),
  );

  Future<void> _apply() async {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresá un número válido mayor a 0'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_mode == 'set') {
        await FirebaseFirestore.instance
            .collection('users').doc(widget.uid)
            .update({'balance_coins': val});
        DatabaseService().logCoinTransaction(
          uid: widget.uid,
          amount: val - widget.currentCoins,
          type: 'admin_assign',
          description: 'Ajuste manual por admin',
          balanceAfter: val,
        );
      } else {
        final delta = _mode == 'add' ? val : -val;
        await FirebaseFirestore.instance
            .collection('users').doc(widget.uid)
            .update({'balance_coins': FieldValue.increment(delta)});
        DatabaseService().logCoinTransaction(
          uid: widget.uid,
          amount: delta,
          type: 'admin_assign',
          description: 'Ajuste manual por admin',
        );
      }
      if (mounted) {
        _ctrl.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mode == 'set'
              ? 'Coins de ${widget.name} → $val'
              : _mode == 'add'
                  ? '+$val coins → ${widget.name}'
                  : '−$val coins de ${widget.name}'),
          backgroundColor: const Color(0xFF1A4D32),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB FINANZAS — ingresos reales de inscripciones
// ─────────────────────────────────────────────────────────────────────────────
class _FinanzasTab extends StatelessWidget {
  const _FinanzasTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _kLime));
        }

        final tournaments = snap.data!.docs;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _sectionLabel('RESUMEN FINANCIERO'),
            const SizedBox(height: 14),
            _FinanzasSummary(tournaments: tournaments),
            const SizedBox(height: 28),
            _sectionLabel('DESGLOSE POR TORNEO'),
            const SizedBox(height: 12),
            ...tournaments.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _TournamentFinanceCard(
                tournamentId: doc.id,
                data: data,
              );
            }),
          ],
        );
      },
    );
  }
}

class _FinanzasSummary extends StatelessWidget {
  final List<QueryDocumentSnapshot> tournaments;
  const _FinanzasSummary({required this.tournaments});

  @override
  Widget build(BuildContext context) {
    // Calcular potencial (costo × capacidad) como referencia
    double potencial = 0;
    for (final t in tournaments) {
      final d = t.data() as Map<String, dynamic>;
      potencial += ((d['costoInscripcion'] ?? 0) as num).toDouble()
          * ((d['playerCount'] ?? 0) as num).toInt();
    }

    return Column(children: [
      // Coins en circulación
      _CoinsCirculationCard(),
      const SizedBox(height: 12),
      // Recaudación potencial
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.orangeAccent.withOpacity(0.15)),
        ),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet,
              color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\$${NumberFormat('#,###').format(potencial)}',
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Text('RECAUDACIÓN POTENCIAL (costo × capacidad)',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${NumberFormat('#,###').format(potencial * 0.10)}',
                style: const TextStyle(
                    color: _kLime,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Text('10% comisión',
                style: TextStyle(color: Colors.white24, fontSize: 9)),
          ]),
        ]),
      ),
    ]);
  }
}

class _TournamentFinanceCard extends StatelessWidget {
  final String tournamentId;
  final Map<String, dynamic> data;
  const _TournamentFinanceCard({
    required this.tournamentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final name    = data['name']?.toString()    ?? 'Torneo';
    final cost    = ((data['costoInscripcion'] ?? 0) as num).toDouble();
    final players = (data['playerCount'] ?? 0) as int;
    final status  = data['status']?.toString()  ?? 'open';
    final clubId  = data['clubId']?.toString()  ?? '';
    final sc      = _statusColor(status);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('inscriptions')
          .snapshots(),
      builder: (ctx, snap) {
        final inscriptos = snap.data?.docs.length ?? 0;
        final real       = cost * inscriptos;
        final comision   = real * 0.10;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sc.withOpacity(0.1)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        color: sc, fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            // Club name
            if (clubId.isNotEmpty)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('clubs').doc(clubId).get(),
                builder: (ctx, cs) {
                  final cName = cs.data?.get('name')?.toString() ?? '';
                  if (cName.isEmpty) return const SizedBox();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(cName,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  );
                },
              ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              _finCell('$inscriptos / $players', 'INSCRIPTOS'),
              _finCell(
                cost > 0 ? '\$${NumberFormat('#,###').format(cost)}' : 'GRATIS',
                'COSTO/JUGADOR',
              ),
              _finCell(
                cost > 0 ? '\$${NumberFormat('#,###').format(real)}' : '—',
                'RECAUDADO',
                highlight: cost > 0,
              ),
              _finCell(
                cost > 0 ? '\$${NumberFormat('#,###').format(comision)}' : '—',
                'COMISIÓN 10%',
                highlight: cost > 0,
                color: _kLime,
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _finCell(String val, String label, {
    bool highlight = false, Color? color,
  }) => Expanded(
    child: Column(children: [
      Text(val,
          style: TextStyle(
              color: color ?? (highlight ? Colors.white : Colors.white60),
              fontSize: 11,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white24, fontSize: 8)),
    ]),
  );
}
