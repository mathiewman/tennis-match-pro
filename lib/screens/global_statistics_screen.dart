import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../models/court_model.dart';
import '../services/database_service.dart';
import 'court_schedule_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPER DE NOVEDADES
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static Future<void> write({
    required String clubId,
    required String type,
    required String message,
    Map<String, dynamic> extra = const {},
  }) async {
    final now     = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    // sortKey = 'yyyyMMddHHmm' — permite orderBy sin índice compuesto
    final sortKey = DateFormat('yyyyMMddHHmm').format(now);
    try {
      await FirebaseFirestore.instance
          .collection('clubs').doc(clubId)
          .collection('notifications')
          .add({
        'type':      type,
        'message':   message,
        'date':      dateStr,
        'time':      timeStr,
        'sortKey':   sortKey,
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE EVENTO DEL DÍA
// ─────────────────────────────────────────────────────────────────────────────
class _DayEvent {
  final String courtId;
  final String courtName;
  final String time;
  final String endTime;
  final String type;        // 'torneo' | 'alquiler' | 'clase_individual' | etc
  final String playerName;  // "N1 vs N2" para torneo, nombre para otros
  final String tournamentId;
  final String tournamentName;

  const _DayEvent({
    required this.courtId,
    required this.courtName,
    required this.time,
    required this.endTime,
    required this.type,
    required this.playerName,
    this.tournamentId = '',
    this.tournamentName = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GlobalStatisticsScreen extends StatefulWidget {
  final String clubId;
  const GlobalStatisticsScreen({super.key, required this.clubId});

  @override
  State<GlobalStatisticsScreen> createState() =>
      _GlobalStatisticsScreenState();
}

class _GlobalStatisticsScreenState extends State<GlobalStatisticsScreen> {
  final WeatherService  _weatherService = WeatherService();
  final DatabaseService _dbService      = DatabaseService();

  DateTime    _selectedDate = DateTime.now();
  DateTime?   _sunsetTime;
  List<Court> _courts       = [];
  bool        _courtsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _loadSunset();
  }

  Future<void> _loadCourts() async {
    final snap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').get();
    if (mounted) setState(() {
      _courts      = snap.docs.map((d) => Court.fromFirestore(d)).toList();
      _courtsLoaded = true;
    });
  }

  Future<void> _loadSunset() async {
    final clubDoc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId).get();
    final GeoPoint? loc = clubDoc.data()?['location'];
    if (loc != null) {
      final s = await _weatherService.getSunsetTime(
          loc.latitude, loc.longitude, _selectedDate);
      if (mounted) setState(() => _sunsetTime = s);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _sunsetTime   = null;
    });
    _loadSunset();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1A),
      appBar: AppBar(
        title: const Text('AGENDA GLOBAL',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFCCFF00),
        backgroundColor: const Color(0xFF1A3A34),
        onRefresh: () async {
          await _loadCourts();
          await _loadSunset();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildDatePicker(),
            if (!_courtsLoaded)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00))),
              )
            else ...[
              _OccupancySummary(
                key:       ValueKey('occ_$_dateStr'),
                clubId:    widget.clubId,
                courts:    _courts,
                dateStr:   _dateStr,
                sunsetTime: _sunsetTime,
              ),
              const SizedBox(height: 16),
              _CourtListSection(
                key:     ValueKey('courts_$_dateStr'),
                clubId:  widget.clubId,
                courts:  _courts,
                dateStr: _dateStr,
                onCourtTap: (court) => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CourtScheduleScreen(
                      clubId:       widget.clubId,
                      courtId:      court.id,
                      courtName:    court.courtName,
                      initialDate:  _selectedDate,
                    ))),
              ),
            ],
            const SizedBox(height: 24),
            _DaySchedule(
              key:     ValueKey('sched_$_dateStr'),
              clubId:  widget.clubId,
              courts:  _courts,
              dateStr: _dateStr,
            ),
            const SizedBox(height: 100),
          ]),
        ),
      ),
    );
  }

  Widget _buildDatePicker() => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    color: Colors.black26,
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
        icon: const Icon(Icons.chevron_left, color: Color(0xFFCCFF00)),
        onPressed: () => _changeDate(-1),
      ),
      Column(children: [
        Text(DateFormat('EEEE', 'es').format(_selectedDate).toUpperCase(),
            style: const TextStyle(
                color: Color(0xFFCCFF00), fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        Text(DateFormat('dd MMMM yyyy', 'es').format(_selectedDate),
            style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
      ]),
      IconButton(
        icon: const Icon(Icons.chevron_right, color: Color(0xFFCCFF00)),
        onPressed: () => _changeDate(1),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RESUMEN DE OCUPACIÓN — cuenta bien los bloques, no los slots individuales
// ─────────────────────────────────────────────────────────────────────────────
class _OccupancySummary extends StatefulWidget {
  final String      clubId;
  final List<Court> courts;
  final String      dateStr;
  final DateTime?   sunsetTime;

  const _OccupancySummary({
    super.key,
    required this.clubId,
    required this.courts,
    required this.dateStr,
    this.sunsetTime,
  });

  @override
  State<_OccupancySummary> createState() => _OccupancySummaryState();
}

class _OccupancySummaryState extends State<_OccupancySummary> {
  final Map<String, int>    _blocks  = {}; // bloques reales por cancha
  final Map<String, double> _revenue = {};
  final List<StreamSubscription> _subs = [];

  @override
  void initState() { super.initState(); _subscribe(); }

  @override
  void didUpdateWidget(_OccupancySummary old) {
    super.didUpdateWidget(old);
    if (old.dateStr != widget.dateStr) { _cancelAll(); _subscribe(); }
  }

  void _subscribe() {
    for (final court in widget.courts) {
      final sub = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(court.id)
          .collection('reservations')
          .where('date', isEqualTo: widget.dateStr)
          .snapshots()
          .listen((snap) {
        // Cada doc = 1 turno de 30 min ocupado
        final occupied = snap.docs.length;

        // Revenue: solo del primer slot de cada bloque (cualquier tipo)
        double rev = 0;
        final seenRev = <String>{};
        for (final d in snap.docs) {
          final data       = d.data();
          final time       = data['time']?.toString()       ?? '';
          final blockStart = data['blockStart']?.toString() ?? '';
          // Si tiene blockStart, solo sumar del primer slot
          if (blockStart.isNotEmpty) {
            final key = blockStart;
            if (seenRev.contains(key)) continue;
            seenRev.add(key);
            if (blockStart != time) continue;
          }
          rev += (data['amount'] ?? 0.0).toDouble();
        }
        if (mounted) setState(() {
          _blocks[court.id]  = occupied;
          _revenue[court.id] = rev;
        });
      });
      _subs.add(sub);
    }
  }

  void _cancelAll() {
    for (final s in _subs) s.cancel();
    _subs.clear(); _blocks.clear(); _revenue.clear();
  }

  @override
  void dispose() { _cancelAll(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final totalBlocks = _blocks.values.fold(0, (a, b) => a + b);
    final totalRev    = _revenue.values.fold(0.0, (a, b) => a + b);
    // Con luz: 7:00-22:00 = 30 turnos. Sin luz: 7:00-20:00 = 26 turnos
    final totalSlots  = widget.courts.fold(0, (sum, c) => sum + (c.hasLights ? 30 : 26));
    final pct         = totalSlots > 0
        ? (totalBlocks / totalSlots).clamp(0.0, 1.0)
        : 0.0;
    final free = (totalSlots - totalBlocks).clamp(0, totalSlots);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('OCUPACIÓN DEL DÍA',
                style: TextStyle(color: Colors.white54, fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            if (widget.sunsetTime != null)
              _Chip('OCASO ${DateFormat('HH:mm').format(widget.sunsetTime!)}',
                  Colors.amber, Icons.wb_twilight),
          ]),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 100, height: 100,
                child: CircularProgressIndicator(
                  value: pct, strokeWidth: 10,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFCCFF00)),
                )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(pct * 100).round()}%',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('ocupación',
                    style: TextStyle(color: Colors.white38, fontSize: 9)),
              ]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StatBadge('$totalBlocks', 'TURNOS OCUPADOS', Colors.orangeAccent),
              const SizedBox(height: 10),
              _StatBadge('$free', 'TURNOS LIBRES', Colors.greenAccent),
              const SizedBox(height: 10),
              _StatBadge('\$${NumberFormat('#,###').format(totalRev)}',
                  'RECAUDADO', const Color(0xFFCCFF00)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA POR CANCHA — conteo correcto de bloques
// ─────────────────────────────────────────────────────────────────────────────
class _CourtListSection extends StatelessWidget {
  final String          clubId;
  final List<Court>     courts;
  final String          dateStr;
  final Function(Court) onCourtTap;

  const _CourtListSection({
    super.key,
    required this.clubId,
    required this.courts,
    required this.dateStr,
    required this.onCourtTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POR CANCHA',
          style: TextStyle(color: Colors.white38, fontSize: 10,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
      const SizedBox(height: 10),
      ...courts.map((c) => _CourtRow(
          clubId: clubId, court: c, dateStr: dateStr,
          onTap: () => onCourtTap(c))),
    ]),
  );
}

class _CourtRow extends StatelessWidget {
  final String       clubId;
  final Court        court;
  final String       dateStr;
  final VoidCallback onTap;

  const _CourtRow({
    required this.clubId, required this.court,
    required this.dateStr, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('clubs').doc(clubId)
        .collection('courts').doc(court.id)
        .collection('reservations')
        .where('date', isEqualTo: dateStr)
        .snapshots(),
    builder: (ctx, snap) {
      final docs     = snap.data?.docs ?? [];
      // Cada doc = 1 turno de 30 min
      final occupied = docs.length;
      // Con luz: 7:00-22:00 = 30 turnos. Sin luz: 7:00-20:00 = 26 turnos
      final total    = court.hasLights ? 30 : 26;
      final pct      = (occupied / total).clamp(0.0, 1.0);
      double revenue = 0;
      final seenRev = <String>{};
      for (final d in docs) {
        final data       = d.data() as Map<String, dynamic>;
        final time       = data['time']?.toString()       ?? '';
        final blockStart = data['blockStart']?.toString() ?? '';
        if (blockStart.isNotEmpty) {
          if (seenRev.contains(blockStart)) continue;
          seenRev.add(blockStart);
          if (blockStart != time) continue;
        }
        revenue += (data['amount'] ?? 0.0).toDouble();
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(court.hasLights ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: court.hasLights ? const Color(0xFFCCFF00) : Colors.white24,
                  size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(court.courtName,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13))),
              Text('\$${NumberFormat('#,###').format(revenue)}',
                  style: const TextStyle(color: Color(0xFFCCFF00),
                      fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 0.8 ? Colors.redAccent
                          : pct >= 0.5 ? Colors.orangeAccent
                          : Colors.greenAccent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$occupied/$total',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ]),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENDA DEL DÍA — eventos programados con análisis de partidos de torneo
// ─────────────────────────────────────────────────────────────────────────────
class _DaySchedule extends StatefulWidget {
  final String      clubId;
  final List<Court> courts;
  final String      dateStr;

  const _DaySchedule({
    super.key,
    required this.clubId,
    required this.courts,
    required this.dateStr,
  });

  @override
  State<_DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends State<_DaySchedule> {
  List<_DayEvent> _events  = [];
  bool            _loading = true;
  String?         _expandedId;
  String          _clubName = '';

  // Suscripciones por cancha
  final List<StreamSubscription> _subs = [];
  // Cache de reservas por cancha
  final Map<String, List<Map<String, dynamic>>> _courtCache = {};

  @override
  void initState() {
    super.initState();
    _loadClubName();
    _subscribe();
  }

  @override
  void didUpdateWidget(_DaySchedule old) {
    super.didUpdateWidget(old);
    if (old.dateStr != widget.dateStr || old.courts != widget.courts) {
      _cancelAll();
      _courtCache.clear();
      _subscribe();
    }
  }

  Future<void> _loadClubName() async {
    final doc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId).get();
    if (mounted) setState(() =>
        _clubName = doc.data()?['name']?.toString() ?? 'el club');
  }

  void _subscribe() {
    if (widget.courts.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    for (final court in widget.courts) {
      final sub = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(court.id)
          .collection('reservations')
          .where('date', isEqualTo: widget.dateStr)
          .snapshots()
          .listen((snap) {
        _courtCache[court.id] = snap.docs
            .map((d) => {'courtId': court.id,
                         'courtName': court.courtName,
                         ...d.data() as Map<String, dynamic>})
            .toList();
        _rebuildEvents();
      });
      _subs.add(sub);
    }
  }

  void _rebuildEvents() {
    final events = <_DayEvent>[];
    final seenBlock  = <String>{};  // courtId_blockStart para bloques de torneo
    final seenTorneo = <String>{};  // tournamentId_playerName para reservas viejas sin blockStart

    for (final docs in _courtCache.values) {
      for (final data in docs) {
        final type       = data['type']?.toString()       ?? '';
        final time       = data['time']?.toString()       ?? '';
        final blockStart = data['blockStart']?.toString() ?? '';
        final courtId    = data['courtId']?.toString()    ?? '';
        final courtName  = data['courtName']?.toString()  ?? '';
        final tourId     = data['tournamentId']?.toString() ?? '';
        final playerName = data['playerName']?.toString()   ?? '';

        if (type == 'torneo') {
          if (blockStart.isNotEmpty) {
            // Nuevo formato: deduplicar por courtId + blockStart
            final key = '${courtId}_$blockStart';
            if (seenBlock.contains(key)) continue;
            seenBlock.add(key);
            // Solo mostrar el primer slot del bloque
            if (blockStart != time) continue;
          } else {
            // Formato viejo (1 slot): deduplicar por tournamentId + playerName
            final key = '${tourId}_$playerName';
            if (seenTorneo.contains(key)) continue;
            seenTorneo.add(key);
          }
        }

        // Ignorar solo reservas de torneo secundarias (ya deduplicadas arriba)
        // Mostrar todo lo demás incluido reservas sin nombre

        // Para no-torneo, usar time directamente (blockStart no aplica)
        final displayTime = (type == 'torneo' && blockStart.isNotEmpty)
            ? blockStart
            : time;

        // Saltar si no tiene hora (doc corrupto)
        if (displayTime.isEmpty) continue;

        events.add(_DayEvent(
          courtId:        courtId,
          courtName:      courtName,
          time:           displayTime,
          endTime:        data['blockEnd']?.toString() ?? '',
          type:           type,
          playerName:     playerName,
          tournamentId:   tourId,
          tournamentName: '',
        ));
      }
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    if (mounted) setState(() { _events = events; _loading = false; });
  }

  void _cancelAll() {
    for (final s in _subs) s.cancel();
    _subs.clear();
  }

  @override
  void dispose() { _cancelAll(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('AGENDA DEL DÍA',
              style: TextStyle(color: Colors.white38, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('EN VIVO',
                  style: TextStyle(color: Colors.greenAccent,
                      fontSize: 8, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(
              color: Color(0xFFCCFF00)))
        else if (_events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text(
              'No hay eventos programados para este día',
              style: TextStyle(color: Colors.white24, fontSize: 12))),
          )
        else
          ...(_events.map((event) => _EventCard(
            event:      event,
            clubName:   _clubName.isNotEmpty ? _clubName : 'el club',
            isExpanded: _expandedId == _eventId(event),
            onToggle:   () => setState(() =>
              _expandedId = _expandedId == _eventId(event)
                  ? null : _eventId(event)),
          ))),
      ]),
    );
  }

  String _eventId(_DayEvent e) => '${e.courtId}_${e.time}';
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE EVENTO — expandible con análisis del partido
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final _DayEvent event;
  final String    clubName;
  final bool      isExpanded;
  final VoidCallback onToggle;

  const _EventCard({
    required this.event,
    required this.clubName,
    required this.isExpanded,
    required this.onToggle,
  });

  String get _typeLabel {
    switch (event.type) {
      case 'torneo':           return 'TORNEO';
      case 'alquiler':         return 'ALQUILER';
      case 'clase_individual': return 'CLASE INDIVIDUAL';
      case 'clase_grupal':     return 'CLASE GRUPAL';
      case 'manual':           return 'RESERVA WA';
      default:                 return event.type.toUpperCase();
    }
  }

  Color get _typeColor {
    switch (event.type) {
      case 'torneo':           return Colors.orangeAccent;
      case 'alquiler':         return const Color(0xFFCCFF00);
      case 'clase_individual': return Colors.blueAccent;
      case 'clase_grupal':     return Colors.purpleAccent;
      default:                 return Colors.white54;
    }
  }

  String _buildHeadline() {
    final timeStr = event.endTime.isNotEmpty
        ? '${event.time} – ${event.endTime}hs'
        : '${event.time}hs';

    if (event.type == 'torneo' && event.playerName.contains(' vs ')) {
      final parts = event.playerName.split(' vs ');
      final n1    = parts[0].trim();
      final n2    = parts.length > 1 ? parts[1].trim() : '?';
      final tour  = event.tournamentName.isNotEmpty
          ? 'del torneo ${event.tournamentName}'
          : 'de torneo';
      return 'Hoy a las $timeStr se juega un partido $tour entre $n1 y $n2 en ${event.courtName} de $clubName.';
    }

    return '${_typeLabel}: ${event.playerName.isNotEmpty ? event.playerName : 'Sin nombre'} — ${event.courtName} a las $timeStr.';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _typeColor.withOpacity(isExpanded ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _typeColor.withOpacity(isExpanded ? 0.35 : 0.15)),
        ),
        child: Column(children: [
          // ── Cabecera ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Hora
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(event.time,
                    style: TextStyle(
                        color: _typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 12),

              // Texto
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_typeLabel,
                      style: TextStyle(
                          color: _typeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(
                    event.type == 'torneo' && event.playerName.contains(' vs ')
                        ? event.playerName
                        : event.playerName.isNotEmpty
                            ? event.playerName
                            : event.courtName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(event.courtName,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ]),
              ),

              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down,
                    color: _typeColor.withOpacity(0.7), size: 20),
              ),
            ]),
          ),

          // ── Detalle expandido ─────────────────────────────────────────────
          if (isExpanded) ...[
            if (event.type == 'torneo')
              _MatchAnalysis(
                event:    event,
                headline: _buildHeadline(),
              )
            else
              _EventDetail(event: event),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANÁLISIS DEL PARTIDO — relato con stats reales
// ─────────────────────────────────────────────────────────────────────────────
class _MatchAnalysis extends StatefulWidget {
  final _DayEvent event;
  final String    headline;
  const _MatchAnalysis({required this.event, required this.headline});

  @override
  State<_MatchAnalysis> createState() => _MatchAnalysisState();
}

class _MatchAnalysisState extends State<_MatchAnalysis> {
  Map<String, dynamic>? _stats1;
  Map<String, dynamic>? _stats2;
  List<Map<String, dynamic>> _history1 = []; // partidos anteriores de n1
  List<Map<String, dynamic>> _history2 = []; // partidos anteriores de n2
  bool _loading = true;

  String get _n1 => widget.event.playerName.split(' vs ')[0].trim();
  String get _n2 {
    final p = widget.event.playerName.split(' vs ');
    return p.length > 1 ? p[1].trim() : '?';
  }

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    if (widget.event.tournamentId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Stats del annual_stats del torneo
      final year = DateTime.now().year.toString();
      final statsSnap = await FirebaseFirestore.instance
          .collection('tournaments').doc(widget.event.tournamentId)
          .collection('annual_stats').doc(year).get();

      if (statsSnap.exists) {
        final players = (statsSnap.data()?['players'] as List?) ?? [];
        for (final p in players) {
          final name = (p['name'] ?? '').toString().toUpperCase();
          if (name == _n1.toUpperCase()) _stats1 = Map<String, dynamic>.from(p);
          if (name == _n2.toUpperCase()) _stats2 = Map<String, dynamic>.from(p);
        }
      }

      // 2. Leer slots del bracket para armar historial de partidos
      final layoutSnap = await FirebaseFirestore.instance
          .collection('tournaments').doc(widget.event.tournamentId)
          .collection('temp_layout').doc('current').get();

      if (layoutSnap.exists) {
        final raw = layoutSnap.data()?['slots'];
        if (raw is Map) {
          final slots = raw.map((k, v) => MapEntry(
              k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}));

          // Recorrer slots de 2 en 2 para encontrar partidos jugados
          final slotList = slots.entries.toList()
            ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

          for (int i = 0; i < slotList.length - 1; i += 2) {
            final s1   = slotList[i].value;
            final s2   = slotList[i + 1].value;
            final name1 = (s1['name'] ?? '').toString();
            final name2 = (s2['name'] ?? '').toString();
            final score = (s1['score'] as List?) ?? [];

            // Solo slots con resultado cargado
            if (score.isEmpty) continue;
            if (name1.isEmpty || name2.isEmpty) continue;
            if (name1 == 'BYE' || name2 == 'BYE') continue;

            final winner1 = s1['winner'] == true;
            final specialResult = s1['specialResult']?.toString() ?? 'normal';
            final absent1  = s1['absent']   == true;
            final absent2  = s2['absent']   == true;
            final abandono1 = s1['abandono'] == true;
            final abandono2 = s2['abandono'] == true;

            // Determinar ganador y perdedor
            String winner, loser, winnerScore, loserScore;
            bool wonByWO = specialResult == 'walkover';
            bool wonByABD = specialResult == 'abandono';

            if (winner1) {
              winner = name1; loser = name2;
            } else {
              winner = name2; loser = name1;
            }

            // Formatear score como "6-2, 6-1"
            winnerScore = score.map((s) {
              final parts = s.toString().split('-');
              if (parts.length == 2) {
                final a = int.tryParse(parts[0]) ?? 0;
                final b = int.tryParse(parts[1]) ?? 0;
                return winner == name1 ? '$a-$b' : '$b-$a';
              }
              return s.toString();
            }).where((s) => s != '0-0').join(', ');

            // Agregar al historial del jugador 1
            if (name1.toUpperCase() == _n1.toUpperCase() ||
                name2.toUpperCase() == _n1.toUpperCase()) {
              final isN1Winner = winner.toUpperCase() == _n1.toUpperCase();
              _history1.add({
                'opponent': isN1Winner ? loser : winner,
                'won':      isN1Winner,
                'score':    winnerScore,
                'special':  specialResult,
                'absent':   isN1Winner ? absent2 : absent1,
                'abandono': isN1Winner ? abandono2 : abandono1,
              });
            }

            // Agregar al historial del jugador 2
            if (name1.toUpperCase() == _n2.toUpperCase() ||
                name2.toUpperCase() == _n2.toUpperCase()) {
              final isN2Winner = winner.toUpperCase() == _n2.toUpperCase();
              _history2.add({
                'opponent': isN2Winner ? loser : winner,
                'won':      isN2Winner,
                'score':    winnerScore,
                'special':  specialResult,
                'absent':   isN2Winner ? absent2 : absent1,
                'abandono': isN2Winner ? abandono2 : abandono1,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('_loadStats error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: Colors.white.withOpacity(0.08)),
        const SizedBox(height: 8),

        // Headline del partido
        Text(widget.headline,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.5)),
        const SizedBox(height: 16),

        if (_loading)
          const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFFCCFF00), strokeWidth: 2)))
        else ...[
          // Tabla comparativa
          _buildComparison(),
          const SizedBox(height: 16),
          // Relato con historial real
          _buildNarrative(),
        ],
      ]),
    );
  }

  Widget _buildComparison() {
    final pj1   = (_stats1?['pj']         ?? 0) as int;
    final pg1   = (_stats1?['pg']         ?? 0) as int;
    final pp1   = (_stats1?['pp']         ?? 0) as int;
    final pct1  = pj1 > 0 ? (pg1 / pj1 * 100).round() : 0;
    final str1  = (_stats1?['streak']     ?? 0) as int;
    final strT1 = (_stats1?['streakType'] ?? '') as String;
    final pts1  = (_stats1?['totalPts']   ?? _stats1?['rankingPts'] ?? 0) as int;

    final pj2   = (_stats2?['pj']         ?? 0) as int;
    final pg2   = (_stats2?['pg']         ?? 0) as int;
    final pp2   = (_stats2?['pp']         ?? 0) as int;
    final pct2  = pj2 > 0 ? (pg2 / pj2 * 100).round() : 0;
    final str2  = (_stats2?['streak']     ?? 0) as int;
    final strT2 = (_stats2?['streakType'] ?? '') as String;
    final pts2  = (_stats2?['totalPts']   ?? _stats2?['rankingPts'] ?? 0) as int;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(_n1.toUpperCase(),
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 11),
              overflow: TextOverflow.ellipsis)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('VS', style: TextStyle(color: Colors.white24,
                fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(_n2.toUpperCase(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 11),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        _statRow('PJ',  '$pj1',  '$pj2'),
        _statRow('PG',  '$pg1',  '$pg2',  w: pg1 > pg2 ? 1 : pg2 > pg1 ? 2 : 0),
        _statRow('PP',  '$pp1',  '$pp2'),
        _statRow('%G',  '$pct1%','$pct2%', w: pct1 > pct2 ? 1 : pct2 > pct1 ? 2 : 0),
        _statRow('PTS', '$pts1', '$pts2',  w: pts1 > pts2 ? 1 : pts2 > pts1 ? 2 : 0),
        if (str1 > 0 || str2 > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: str1 > 0
                ? Text('${strT1 == 'W' ? '🔥' : '📉'} $str1 ${strT1 == 'W' ? 'victorias' : 'derrotas'} seguidas',
                    style: TextStyle(
                        color: strT1 == 'W' ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 9))
                : const SizedBox()),
            Expanded(child: str2 > 0
                ? Text('${strT2 == 'W' ? '🔥' : '📉'} $str2 ${strT2 == 'W' ? 'victorias' : 'derrotas'} seguidas',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: strT2 == 'W' ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 9))
                : const SizedBox()),
          ]),
        ],
      ]),
    );
  }

  Widget _statRow(String label, String v1, String v2, {int w = 0}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(v1, style: TextStyle(
              color: w == 1 ? const Color(0xFFCCFF00) : Colors.white70,
              fontSize: 12,
              fontWeight: w == 1 ? FontWeight.bold : FontWeight.normal))),
          SizedBox(width: 36,
              child: Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white24,
                      fontSize: 9, fontWeight: FontWeight.bold))),
          Expanded(child: Text(v2, textAlign: TextAlign.right,
              style: TextStyle(
                  color: w == 2 ? const Color(0xFFCCFF00) : Colors.white70,
                  fontSize: 12,
                  fontWeight: w == 2 ? FontWeight.bold : FontWeight.normal))),
        ]),
      );

  Widget _buildNarrative() {
    final pj1   = (_stats1?['pj']         ?? 0) as int;
    final pg1   = (_stats1?['pg']         ?? 0) as int;
    final pj2   = (_stats2?['pj']         ?? 0) as int;
    final pg2   = (_stats2?['pg']         ?? 0) as int;
    final pct1  = pj1 > 0 ? (pg1 / pj1 * 100).round() : 0;
    final pct2  = pj2 > 0 ? (pg2 / pj2 * 100).round() : 0;
    final str1  = (_stats1?['streak']     ?? 0) as int;
    final str2  = (_stats2?['streak']     ?? 0) as int;
    final strT1 = (_stats1?['streakType'] ?? '') as String;
    final strT2 = (_stats2?['streakType'] ?? '') as String;
    final pts1  = (_stats1?['totalPts']   ?? _stats1?['rankingPts'] ?? 0) as int;
    final pts2  = (_stats2?['totalPts']   ?? _stats2?['rankingPts'] ?? 0) as int;

    final buf = StringBuffer();

    // ── Relato de N1 ─────────────────────────────────────────────────────────
    buf.write('🎾 $_n1 ');

    if (_history1.isEmpty && pj1 == 0) {
      buf.write('llega a este partido sin historial en el torneo. ');
    } else {
      // Último partido
      if (_history1.isNotEmpty) {
        final last = _history1.last;
        final opp  = last['opponent']?.toString() ?? '';
        final won  = last['won'] == true;
        final score = last['score']?.toString() ?? '';
        final special = last['special']?.toString() ?? 'normal';

        if (special == 'walkover') {
          // absent = true significa que ESE jugador fue el ausente
          final wasAbsent = last['absent'] == true;
          if (wasAbsent) {
            // Este jugador no se presentó — perdió
            buf.write('no se presentó en su último partido contra $opp (W.O.). ');
          } else {
            // Este jugador ganó porque el otro no se presentó
            buf.write('avanzó por W.O. en su último partido — $opp no se presentó. ');
          }
        } else if (special == 'abandono') {
          final wasAbandono = last['abandono'] == true;
          if (wasAbandono) {
            buf.write('abandonó su último partido contra $opp. ');
          } else {
            // Este jugador ganó porque el otro abandonó
            buf.write('avanzó en su último partido — $opp abandonó');
            if (score.isNotEmpty) buf.write(' (score al momento: $score)');
            buf.write('. ');
          }
        } else if (won) {
          buf.write('viene de ganarle a $opp');
          if (score.isNotEmpty) buf.write(' por $score');
          buf.write('. ');
        } else {
          buf.write('viene de caer ante $opp');
          if (score.isNotEmpty) buf.write(' por $score');
          buf.write('. ');
        }
      }

      // Racha
      if (str1 > 1 && strT1 == 'W') {
        buf.write('Viene en racha ganadora de $str1 partidos consecutivos. ');
      } else if (str1 > 1 && strT1 == 'L') {
        buf.write('Llega en una mala racha de $str1 derrotas seguidas. ');
      }

      // Rendimiento general
      if (pj1 > 0) {
        buf.write('En el torneo acumula $pg1 victorias en $pj1 partidos (${pct1}%). ');
      }
    }

    buf.write('\n\n');

    // ── Relato de N2 ─────────────────────────────────────────────────────────
    buf.write('🎾 $_n2 ');

    if (_history2.isEmpty && pj2 == 0) {
      buf.write('también debuta con pizarrón en blanco en el torneo. ');
    } else {
      if (_history2.isNotEmpty) {
        final last  = _history2.last;
        final opp   = last['opponent']?.toString() ?? '';
        final won   = last['won'] == true;
        final score = last['score']?.toString() ?? '';
        final special = last['special']?.toString() ?? 'normal';

        if (special == 'walkover') {
          final wasAbsent = last['absent'] == true;
          if (wasAbsent) {
            buf.write('no se presentó en su último partido contra $opp (W.O.). ');
          } else {
            buf.write('avanzó por W.O. en su último partido — $opp no se presentó. ');
          }
        } else if (special == 'abandono') {
          final wasAbandono = last['abandono'] == true;
          if (wasAbandono) {
            buf.write('abandonó su último partido contra $opp. ');
          } else {
            buf.write('avanzó en su último partido — $opp abandonó');
            if (score.isNotEmpty) buf.write(' (score al momento: $score)');
            buf.write('. ');
          }
        } else if (won) {
          buf.write('viene de ganarle a $opp');
          if (score.isNotEmpty) buf.write(' por $score');
          buf.write('. ');
        } else {
          buf.write('viene de caer ante $opp');
          if (score.isNotEmpty) buf.write(' por $score');
          buf.write('. ');
        }
      }

      if (str2 > 1 && strT2 == 'W') {
        buf.write('Viene en racha ganadora de $str2 partidos seguidos. ');
      } else if (str2 > 1 && strT2 == 'L') {
        buf.write('Llega en mala racha con $str2 derrotas consecutivas. ');
      }

      if (pj2 > 0) {
        buf.write('Tiene $pg2 victorias en $pj2 partidos en el torneo (${pct2}%). ');
      }
    }

    buf.write('\n\n');

    // ── Conclusión ────────────────────────────────────────────────────────────
    if (pts1 > pts2 + 5) {
      buf.write('📊 En el ranking, $_n1 lidera con $pts1 pts contra $pts2 de $_n2. ');
    } else if (pts2 > pts1 + 5) {
      buf.write('📊 $_n2 va mejor en el ranking con $pts2 pts vs $pts1 de $_n1. ');
    }

    if (pct1 > pct2 + 20 && str1 > 0 && strT1 == 'W') {
      buf.write('$_n1 llega como claro favorito por rendimiento y momento. 💪');
    } else if (pct2 > pct1 + 20 && str2 > 0 && strT2 == 'W') {
      buf.write('$_n2 llega como favorito según los números y la racha. 💪');
    } else if (_history1.isEmpty && _history2.isEmpty) {
      buf.write('Ambos debutan sin historial en el torneo. Todo está por decidirse en la cancha. 🎾');
    } else {
      buf.write('El partido se presenta parejo. La cancha dirá la última palabra. 🎾');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(buf.toString(),
          style: const TextStyle(
              color: Colors.white60, fontSize: 12, height: 1.7)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE DE EVENTO — para clases, alquileres y reservas WA
// ─────────────────────────────────────────────────────────────────────────────
class _EventDetail extends StatelessWidget {
  final _DayEvent event;
  const _EventDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.type == 'clase_individual' ? Colors.blueAccent
        : event.type == 'clase_grupal' ? Colors.purpleAccent
        : event.type == 'manual' ? Colors.white54
        : const Color(0xFFCCFF00);

    final timeStr = event.endTime.isNotEmpty
        ? '${event.time} – ${event.endTime}hs'
        : '${event.time}hs';

    String detalle;
    String emoji;
    switch (event.type) {
      case 'clase_individual':
        emoji   = '📚';
        detalle = event.playerName.isNotEmpty
            ? 'Clase individual con ${event.playerName} en ${event.courtName} a las $timeStr.'
            : 'Clase individual en ${event.courtName} a las $timeStr.';
        break;
      case 'clase_grupal':
        emoji   = '👥';
        detalle = event.playerName.isNotEmpty
            ? 'Clase grupal — ${event.playerName} — en ${event.courtName} a las $timeStr.'
            : 'Clase grupal en ${event.courtName} a las $timeStr.';
        break;
      case 'manual':
        emoji   = '📲';
        detalle = event.playerName.isNotEmpty
            ? 'Reserva por WhatsApp de ${event.playerName} en ${event.courtName} a las $timeStr.'
            : 'Reserva por WhatsApp en ${event.courtName} a las $timeStr.';
        break;
      default:
        emoji   = '🎾';
        detalle = event.playerName.isNotEmpty
            ? 'Alquiler de cancha — ${event.playerName} — en ${event.courtName} a las $timeStr.'
            : 'Alquiler de cancha en ${event.courtName} a las $timeStr.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: Colors.white.withOpacity(0.08)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(detalle,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.5)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  const _Chip(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _StatBadge(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(
              color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
        ]),
      ]);
}
