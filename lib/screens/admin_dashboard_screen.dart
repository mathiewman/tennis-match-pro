import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'club_dashboard_screen.dart';
import 'tournament_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PANEL DE ADMINISTRACIÓN',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5)),
            Text('Vista global de la plataforma',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFCCFF00),
          indicatorWeight: 2,
          labelColor: const Color(0xFFCCFF00),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'RESUMEN'),
            Tab(text: 'CLUBES'),
            Tab(text: 'TORNEOS'),
            Tab(text: 'USUARIOS'),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB RESUMEN — stats globales de la plataforma
// ─────────────────────────────────────────────────────────────────────────────
class _ResumenTab extends StatelessWidget {
  const _ResumenTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ESTADÍSTICAS GLOBALES',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 16),

        // Grid de stats
        Row(children: [
          Expanded(child: _StatCard(
            label: 'CLUBES',
            icon: Icons.stadium,
            color: Colors.blueAccent,
            stream: FirebaseFirestore.instance
                .collection('clubs').snapshots(),
            countDocs: true,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: 'TORNEOS',
            icon: Icons.emoji_events,
            color: Colors.orangeAccent,
            stream: FirebaseFirestore.instance
                .collection('tournaments').snapshots(),
            countDocs: true,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(
            label: 'JUGADORES',
            icon: Icons.groups,
            color: const Color(0xFFCCFF00),
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'player')
                .snapshots(),
            countDocs: true,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: 'COORDINADORES',
            icon: Icons.manage_accounts,
            color: Colors.purpleAccent,
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'coordinator')
                .snapshots(),
            countDocs: true,
          )),
        ]),

        const SizedBox(height: 28),
        const Text('ACTIVIDAD RECIENTE',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 12),
        _RecentActivity(),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String      label;
  final IconData    icon;
  final Color       color;
  final Stream<QuerySnapshot> stream;
  final bool        countDocs;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    this.countDocs = false,
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
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
    // Últimas novedades de todos los clubes — collectionGroup
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('notifications')
          .limit(15)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCCFF00)));

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('Sin actividad reciente',
                style: TextStyle(color: Colors.white24))),
          );
        }

        // Ordenar en memoria
        final sorted = docs.toList()
          ..sort((a, b) {
            final ka = (a.data() as Map)['sortKey']?.toString() ?? '';
            final kb = (b.data() as Map)['sortKey']?.toString() ?? '';
            return kb.compareTo(ka);
          });

        return Column(
          children: sorted.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final msg  = data['message']?.toString() ?? '';
            final time = data['time']?.toString()    ?? '';
            final date = data['date']?.toString()    ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Expanded(child: Text(msg,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11))),
                const SizedBox(width: 8),
                Text('$date $time',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 9)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB CLUBES
// ─────────────────────────────────────────────────────────────────────────────
class _ClubesTab extends StatelessWidget {
  const _ClubesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCCFF00)));

        final clubs = snap.data!.docs;
        if (clubs.isEmpty) {
          return const Center(child: Text('Sin clubes registrados',
              style: TextStyle(color: Colors.white38)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: clubs.length,
          itemBuilder: (ctx, i) {
            final data = clubs[i].data() as Map<String, dynamic>;
            final id   = clubs[i].id;
            final name = data['name']?.toString() ?? 'Club sin nombre';
            final addr = data['address']?.toString() ?? '';
            final courts = data['courtCount'] ?? 0;

            return GestureDetector(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => ClubDashboardScreen(clubId: id))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.stadium,
                        color: Colors.blueAccent, size: 22),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$courts canchas',
                          style: const TextStyle(
                              color: Color(0xFFCCFF00),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      const Icon(Icons.chevron_right,
                          color: Colors.white24, size: 16),
                    ],
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB TORNEOS — todos los torneos de todos los clubes
// ─────────────────────────────────────────────────────────────────────────────
class _TorneosTab extends StatelessWidget {
  const _TorneosTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: Color(0xFFCCFF00)));

        final torneos = snap.data!.docs;
        if (torneos.isEmpty) {
          return const Center(child: Text('Sin torneos registrados',
              style: TextStyle(color: Colors.white38)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: torneos.length,
          itemBuilder: (ctx, i) {
            final data     = torneos[i].data() as Map<String, dynamic>;
            final id       = torneos[i].id;
            final name     = data['name']?.toString()     ?? 'Torneo';
            final category = data['category']?.toString() ?? '';
            final clubId   = data['clubId']?.toString()   ?? '';
            final players  = data['playerCount']          ?? 16;
            final status   = data['status']?.toString()   ?? 'setup';

            Color statusColor;
            String statusLabel;
            switch (status) {
              case 'active': statusColor = Colors.greenAccent;  statusLabel = 'EN CURSO'; break;
              case 'done':   statusColor = Colors.white38;      statusLabel = 'FINALIZADO'; break;
              default:       statusColor = Colors.orangeAccent; statusLabel = 'ARMANDO';
            }

            return GestureDetector(
              onTap: clubId.isNotEmpty ? () => Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => TournamentManagementScreen(
                    clubId:         clubId,
                    tournamentId:   id,
                    tournamentName: name,
                    playerCount:    players,
                  ))) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.12)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_events,
                        color: Colors.orangeAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Row(children: [
                        Text(category,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        const Text(' · ',
                            style: TextStyle(color: Colors.white24)),
                        Text('$players jugadores',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ]),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB USUARIOS — todos los usuarios registrados
// ─────────────────────────────────────────────────────────────────────────────
class _UsuariosTab extends StatefulWidget {
  const _UsuariosTab();

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('users');
    if (_filter != 'all') {
      query = query.where('role', isEqualTo: _filter);
    }

    return Column(children: [
      // Filtro por rol
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('Todos',         'all',         Colors.white54),
            _filterChip('Jugadores',     'player',      const Color(0xFFCCFF00)),
            _filterChip('Coordinadores', 'coordinator', Colors.purpleAccent),
            _filterChip('Admins',        'admin',       Colors.redAccent),
            _filterChip('Coaches',       'coach',       Colors.blueAccent),
          ]),
        ),
      ),

      // Lista
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: query.limit(100).snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00)));

            final users = snap.data!.docs;
            if (users.isEmpty) {
              return const Center(child: Text('Sin usuarios',
                  style: TextStyle(color: Colors.white38)));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              itemCount: users.length,
              itemBuilder: (ctx, i) {
                final data  = users[i].data() as Map<String, dynamic>;
                final name  = data['displayName']?.toString() ?? 'Sin nombre';
                final email = data['email']?.toString()       ?? '';
                final role  = data['role']?.toString()        ?? 'pending';
                final photo = data['photoURL']?.toString()    ?? '';
                final coins = data['balance_coins']           ?? 0;

                Color roleColor;
                switch (role) {
                  case 'admin':       roleColor = Colors.redAccent;      break;
                  case 'coordinator': roleColor = Colors.purpleAccent;   break;
                  case 'coach':       roleColor = Colors.blueAccent;     break;
                  case 'player':      roleColor = const Color(0xFFCCFF00); break;
                  default:            roleColor = Colors.white24;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: roleColor.withOpacity(0.15),
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.bold))
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
                                color: Colors.white38,
                                fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(role.toUpperCase(),
                              style: TextStyle(
                                  color: roleColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        Text('$coins coins',
                            style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 9)),
                      ],
                    ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _filterChip(String label, String value, Color color) =>
      GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
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
