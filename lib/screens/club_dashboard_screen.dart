import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'court_management_screen.dart';
import 'global_statistics_screen.dart';
import 'tournament_list_screen.dart';
import 'pricing_config_screen.dart';
import 'club_store_screen.dart';
import 'players_management_screen.dart';

class ClubDashboardScreen extends StatefulWidget {
  final String clubId;
  const ClubDashboardScreen({super.key, required this.clubId});

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1A),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CENTRO DE MANDOS',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2)),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clubs').doc(widget.clubId).snapshots(),
            builder: (ctx, snap) {
              final name = snap.hasData && snap.data!.exists
                  ? (snap.data!.data() as Map<String, dynamic>)['name'] ?? ''
                  : '';
              return Text(name.toString().toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFFCCFF00),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5));
            },
          ),
        ]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dlgCtx) => AlertDialog(
                  backgroundColor: const Color(0xFF0D1F1A),
                  title: const Text('Cerrar sesión',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  content: const Text('¿Salir de tu cuenta?',
                      style: TextStyle(color: Colors.white54)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dlgCtx, false),
                      child: const Text('CANCELAR',
                          style: TextStyle(color: Colors.white38)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00)),
                      onPressed: () => Navigator.pop(dlgCtx, true),
                      child: const Text('SALIR',
                          style: TextStyle(color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await FirebaseAuth.instance.signOut();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFCCFF00),
        backgroundColor: const Color(0xFF1A3A34),
        onRefresh: () async {
          setState(() => _refreshKey++);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── AGENDA DE HOY ──────────────────────────────────────────────────
          _TodayAgendaCard(key: ValueKey(_refreshKey), clubId: widget.clubId),
          const SizedBox(height: 24),

          // ── GRID ───────────────────────────────────────────────────────────
          const Text('ACCESOS RÁPIDOS',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _gridItem(context,
                  title: 'TORNEOS',
                  icon: Icons.emoji_events,
                  color: Colors.orangeAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => TournamentListScreen(clubId: widget.clubId)))),
              _gridItem(context,
                  title: 'CANCHAS',
                  icon: Icons.sports_tennis,
                  color: const Color(0xFFCCFF00),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => CourtManagementScreen(clubId: widget.clubId)))),
              _gridItem(context,
                  title: 'JUGADORES',
                  icon: Icons.groups,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => PlayersManagementScreen(
                              clubId: widget.clubId)))),
              _gridItem(context,
                  title: 'TARIFAS',
                  icon: Icons.attach_money,
                  color: const Color(0xFFCCFF00),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PricingConfigScreen(clubId: widget.clubId)))),
              _gridItem(context,
                  title: 'TIENDA',
                  icon: Icons.storefront,
                  color: Colors.tealAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => ClubStoreScreen(
                              clubId:   widget.clubId,
                              clubName: '')))),
              _gridItem(context,
                  title: 'AGENDA',
                  icon: Icons.bar_chart_rounded,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              GlobalStatisticsScreen(clubId: widget.clubId)))),
            ],
          ),
          const SizedBox(height: 28),

          // ── NOVEDADES ──────────────────────────────────────────────────────
          _NewsSection(clubId: widget.clubId),
          const SizedBox(height: 40),
        ]),
        ),
      ),
    );
  }

  Widget _gridItem(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title,
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
// AGENDA DE HOY — resumen completo del día actual
// ─────────────────────────────────────────────────────────────────────────────
class _TodayAgendaCard extends StatefulWidget {
  final String clubId;
  const _TodayAgendaCard({super.key, required this.clubId});

  @override
  State<_TodayAgendaCard> createState() => _TodayAgendaCardState();
}

class _TodayAgendaCardState extends State<_TodayAgendaCard> {
  final String _dateStr =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Contadores por tipo
  int    _totalReservas   = 0;
  int    _torneos         = 0;
  int    _claseInd        = 0;
  int    _claseGrup       = 0;
  int    _alquileres      = 0;
  double _recaudacion     = 0;
  bool   _loaded          = false;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  // Datos por cancha acumulados en tiempo real
  final Map<String, List<Map<String, dynamic>>> _courtDocs = {};

  void _subscribe() async {
    final courtsSnap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').get();

    for (final court in courtsSnap.docs) {
      final sub = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(court.id)
          .collection('reservations')
          .where('date', isEqualTo: _dateStr)
          .snapshots()
          .listen((snap) {
        // Guardar los docs de esta cancha y recalcular todo en memoria
        _courtDocs[court.id] = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
        _recalculateFromCache(court.id);
      });
      _subs.add(sub);
    }
  }

  void _recalculateFromCache(String updatedCourtId) {
    int    total   = 0;
    int    torneos = 0;
    int    claseI  = 0;
    int    claseG  = 0;
    int    alq     = 0;
    double rev     = 0;
    // Deduplicar bloques de múltiples slots: courtId_blockStart
    final seenBlocks = <String>{};

    for (final entry in _courtDocs.entries) {
      final courtId = entry.key;
      for (final data in entry.value) {
        final type       = data['type']?.toString()       ?? '';
        final time       = data['time']?.toString()       ?? '';
        final blockStart = data['blockStart']?.toString() ?? '';

        // Para cualquier reserva que tenga blockStart (bloque de múltiples slots),
        // contar solo el primer slot del bloque
        if (blockStart.isNotEmpty) {
          final key = '${courtId}_$blockStart';
          if (seenBlocks.contains(key)) continue;
          seenBlocks.add(key);
          // Si este doc no es el primer slot del bloque, saltarlo
          if (blockStart != time) continue;
        }

        total++;
        switch (type) {
          case 'torneo':           torneos++; break;
          case 'clase_individual': claseI++;  break;
          case 'clase_grupal':     claseG++;  break;
          case 'alquiler':
          case 'manual':
          default:                 alq++;     break;
        }
        if (type != 'torneo') {
          rev += (data['amount'] ?? 0.0).toDouble();
        }
      }
    }

    if (mounted) setState(() {
      _totalReservas = total;
      _torneos       = torneos;
      _claseInd      = claseI;
      _claseGrup     = claseG;
      _alquileres    = alq;
      _recaudacion   = rev;
      _loaded        = true;
    });
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFF00).withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ─────────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.today, color: Color(0xFFCCFF00), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AGENDA DE HOY',
                  style: TextStyle(color: Color(0xFFCCFF00),
                      fontWeight: FontWeight.bold, fontSize: 12,
                      letterSpacing: 1.5)),
              Text(
                DateFormat("EEEE dd 'de' MMMM", 'es')
                    .format(DateTime.now()).toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ]),
          ),
          // Ver detalle completo
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => GlobalStatisticsScreen(clubId: widget.clubId))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('VER DETALLE',
                  style: TextStyle(color: Color(0xFFCCFF00),
                      fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        if (!_loaded)
          const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFFCCFF00), strokeWidth: 2)))
        else ...[
          // ── Recaudación ────────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.attach_money, color: Color(0xFFCCFF00), size: 20),
            const SizedBox(width: 6),
            Text('\$${NumberFormat('#,###').format(_recaudacion)}',
                style: const TextStyle(color: Color(0xFFCCFF00),
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Text('recaudado hoy',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(height: 14),

          // ── Desglose ───────────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            _statChip('$_totalReservas', 'TOTAL', Colors.white70),
            if (_torneos > 0)
              _statChip('$_torneos', 'TORNEOS', Colors.orangeAccent),
            if (_alquileres > 0)
              _statChip('$_alquileres', 'ALQUILERES', const Color(0xFFCCFF00)),
            if (_claseInd > 0)
              _statChip('$_claseInd', 'CLASES IND.', Colors.blueAccent),
            if (_claseGrup > 0)
              _statChip('$_claseGrup', 'CLASES GRUP.', Colors.purpleAccent),
            if (_totalReservas == 0)
              const Text('Sin reservas por el momento',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }

  Widget _statChip(String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE NOVEDADES
// ─────────────────────────────────────────────────────────────────────────────
class _NewsSection extends StatefulWidget {
  final String clubId;
  const _NewsSection({required this.clubId});

  @override
  State<_NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<_NewsSection> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        const Text('NOVEDADES DE HOY',
            style: TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _showHistory = !_showHistory),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _showHistory ? 'SOLO HOY' : 'VER HISTORIAL',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      StreamBuilder<QuerySnapshot>(
        stream: _showHistory
            ? FirebaseFirestore.instance
                .collection('clubs').doc(widget.clubId)
                .collection('notifications')
                .limit(50)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('clubs').doc(widget.clubId)
                .collection('notifications')
                .where('date', isEqualTo: todayStr)
                .limit(30)
                .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(
                  color: Color(0xFFCCFF00))),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _showHistory
                      ? 'Sin novedades registradas'
                      : 'Sin novedades hoy todavía',
                  style: const TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            );
          }

          // Ordenar: sortKey desc, fallback date+time
          final sorted = docs.toList()
            ..sort((a, b) {
              final ad = a.data() as Map;
              final bd = b.data() as Map;
              final ka = ad['sortKey']?.toString()
                  ?? '${ad['date'] ?? ''}${(ad['time'] ?? '').toString().replaceAll(':', '')}';
              final kb = bd['sortKey']?.toString()
                  ?? '${bd['date'] ?? ''}${(bd['time'] ?? '').toString().replaceAll(':', '')}';
              return kb.compareTo(ka);
            });

          return Column(
            children: sorted
                .map((d) => _NewsItem(
                    data: d.data() as Map<String, dynamic>,
                    todayStr: todayStr))
                .toList(),
          );
        },
      ),
    ]);
  }
}

class _NewsItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String todayStr;
  const _NewsItem({required this.data, required this.todayStr});

  @override
  Widget build(BuildContext context) {
    final type    = data['type']?.toString()    ?? 'info';
    final message = data['message']?.toString() ?? '';
    final time    = data['time']?.toString()    ?? '';
    final date    = data['date']?.toString()    ?? '';
    final isToday = date == todayStr;

    Color    color;
    IconData icon;
    switch (type) {
      case 'tournament':   color = Colors.orangeAccent;     icon = Icons.emoji_events;          break;
      case 'player_join':  color = Colors.greenAccent;      icon = Icons.person_add;            break;
      case 'player_reg':   color = Colors.blueAccent;       icon = Icons.how_to_reg;            break;
      case 'coins':        color = const Color(0xFFCCFF00); icon = Icons.monetization_on;       break;
      case 'payment':      color = const Color(0xFFCCFF00); icon = Icons.payments;              break;
      case 'reservation':  color = const Color(0xFFCCFF00); icon = Icons.sports_tennis;         break;
      case 'wo':           color = Colors.orangeAccent;     icon = Icons.warning_amber_rounded; break;
      case 'abandono':     color = Colors.redAccent;        icon = Icons.flag;                  break;
      case 'turno':        color = Colors.blueAccent;       icon = Icons.schedule;              break;
      case 'result':       color = Colors.greenAccent;      icon = Icons.scoreboard;            break;
      default:             color = Colors.white38;          icon = Icons.notifications_outlined;break;
    }

    // Formatear fecha y hora de forma legible
    String timeLabel = '';
    if (isToday) {
      timeLabel = time; // "14:30"
    } else if (date.isNotEmpty) {
      // Convertir "2026-03-19" → "19/03"
      try {
        final d = DateTime.parse(date);
        timeLabel = DateFormat('dd/MM').format(d);
        if (time.isNotEmpty) timeLabel += ' $time';
      } catch (_) {
        timeLabel = time;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Ícono
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),

        // Mensaje — ocupa todo el espacio
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.3)),
        ),
        const SizedBox(width: 8),

        // Hora/fecha — ancho fijo para que no desalínee
        if (timeLabel.isNotEmpty)
          SizedBox(
            width: 48,
            child: Text(timeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}
