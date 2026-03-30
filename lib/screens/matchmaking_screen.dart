import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/push_notification_service.dart';

typedef _PlayerDist = ({Player player, double distKm, String clubName});

class MatchmakingScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String        homeClubId;
  const MatchmakingScreen(
      {super.key, this.onBack, this.homeClubId = ''});

  @override
  State<MatchmakingScreen> createState() =>
      _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final _db  = DatabaseService();
  final _loc = LocationService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _slots = [
    '07:00 - 09:00', '09:00 - 11:00', '11:00 - 13:00',
    '14:00 - 16:00', '16:00 - 18:00', '18:00 - 20:00', '20:00 - 22:00',
  ];

  bool              _loading          = true;
  String            _myLevel          = '';
  Set<String>       _myTimeSlots      = {};   // franjas seleccionadas (multi)
  bool              _myAvailable      = false; // siempre empieza en false
  bool              _availSaving      = false;
  DateTime?         _availableForDate;         // siempre empieza sin fecha
  Position?         _myPosition;
  bool              _showOutside      = false;
  String            _error            = '';
  String            _myName           = '';
  Set<String>       _pendingTo        = {};    // yo les propuse
  Set<String>       _receivedFrom     = {};    // ellos me propusieron

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final myDoc = await _db.getPlayerStream(_uid).first;
      if (!myDoc.exists) {
        setState(() { _loading = false;
          _error = 'Completá tu perfil primero.'; });
        return;
      }
      final me   = Player.fromFirestore(myDoc);
      final data = myDoc.data() as Map<String, dynamic>? ?? {};
      _myLevel     = me.tennisLevel;
      _myName      = me.displayName;
      // Disponibilidad siempre arranca en false (no restaurar sesión anterior)
      _myAvailable      = false;
      _availableForDate = null;
      // Las franjas preferidas sí se restauran (comodidad del usuario)
      final rawSlots = data['availableTimeSlots'] as List?;
      if (rawSlots != null && rawSlots.isNotEmpty) {
        _myTimeSlots = rawSlots.map((e) => e.toString()).toSet();
      } else {
        final single = data['availableTimeSlot']?.toString() ?? '';
        if (single.isNotEmpty) _myTimeSlots = {single};
      }

      try { _myPosition = await _loc.getCurrentPosition(); } catch (_) {}

      // Limpiar solicitudes pendientes antiguas (> 7 días)
      try {
        final cutoff = Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7)));
        final old = await FirebaseFirestore.instance
            .collection('match_requests')
            .where('fromUid', isEqualTo: _uid)
            .where('status', isEqualTo: 'pending')
            .where('createdAt', isLessThan: cutoff)
            .get();
        for (final doc in old.docs) await doc.reference.delete();
      } catch (_) {}

      await _loadPending();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false; _error = e.toString(); });
    }
  }

  // Carga solicitudes enviadas (yo propuse) y recibidas (me propusieron)
  Future<void> _loadPending() async {
    final sent = await FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .get();
    final received = await FirebaseFirestore.instance
        .collection('match_requests')
        .where('toUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (mounted) setState(() {
      _pendingTo    = sent.docs
          .map((d) => d.data()['toUid']?.toString() ?? '')
          .toSet();
      _receivedFrom = received.docs
          .map((d) => d.data()['fromUid']?.toString() ?? '')
          .toSet();
      _loading = false;
    });
  }

  Future<void> _setAvailability(bool val) async {
    setState(() { _availSaving = true; _myAvailable = val; });
    try {
      final slotsList = _myTimeSlots.toList();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'status':              val ? 'disponible' : 'ocupado',
        'availableTimeSlots':  slotsList,
        'availableTimeSlot':   slotsList.join(', '), // compatibilidad
        'availableForDate':    _availableForDate?.toIso8601String(),
        'availableDate':       FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(val
              ? '✅ Disponible para jugar'
              : '⏸ Marcado como no disponible'),
          backgroundColor: val
              ? const Color(0xFF1A4D32)
              : const Color(0xFF2A2A2A),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _availSaving = false);
    }
  }

  void _toggleSlot(String slot) {
    setState(() {
      if (_myTimeSlots.contains(slot)) {
        _myTimeSlots.remove(slot);
      } else {
        _myTimeSlots.add(slot);
      }
    });
    if (_myAvailable) _setAvailability(true);
  }

  Future<void> _pickAvailableDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableForDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFCCFF00),
            onPrimary: Colors.black,
            surface: Color(0xFF2C4A44),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _availableForDate = picked);
    if (_myAvailable) await _setAvailability(true);
  }

  Future<void> _clearAvailableDate() async {
    setState(() => _availableForDate = null);
    if (_myAvailable) await _setAvailability(true);
  }

  /// Acepta una invitación de partido: pide fecha y crea el partido agendado
  Future<void> _acceptInvitation({
    required String docId,
    required String fromUid,
    required String fromName,
    required String timeSlot,
  }) async {
    // 1. Pedir fecha
    DateTime? date;
    String? chosenSlot = timeSlot;

    await showDialog(
      context: context,
      builder: (ctx) {
        DateTime? picked = _availableForDate;
        String localSlot = timeSlot;
        return StatefulBuilder(
          builder: (ctx2, setDialogState) => AlertDialog(
            title: Text('Coordinar con $fromName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Elegí la fecha del partido:',
                    style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx2,
                      initialDate: picked ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFCCFF00),
                            onPrimary: Colors.black,
                            surface: Color(0xFF2C4A44),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (p != null) setDialogState(() => picked = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFF00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFCCFF00).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today,
                          color: Color(0xFFCCFF00), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        picked == null
                            ? 'Tocá para elegir fecha'
                            : DateFormat('EEEE d/MM', 'es').format(picked!),
                        style: TextStyle(
                          color: picked == null
                              ? Colors.white38 : const Color(0xFFCCFF00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Franja horaria:',
                    style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _slots.map((s) => GestureDetector(
                    onTap: () => setDialogState(() => localSlot = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: localSlot == s
                            ? const Color(0xFFCCFF00)
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s,
                        style: TextStyle(
                          color: localSlot == s ? Colors.black : Colors.white54,
                          fontSize: 10,
                          fontWeight: localSlot == s
                              ? FontWeight.bold : FontWeight.normal,
                        )),
                    ),
                  )).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR')),
              ElevatedButton(
                onPressed: picked == null
                    ? null
                    : () {
                        date       = picked;
                        chosenSlot = localSlot;
                        Navigator.pop(ctx);
                      },
                child: const Text('CONFIRMAR')),
            ],
          ),
        );
      },
    );

    if (date == null) return; // usuario canceló

    final dateStr = DateFormat('yyyy-MM-dd').format(date!);
    final dateLbl = DateFormat('d/MM/yyyy', 'es').format(date!);

    // Parse start time from slot for scheduledAt
    DateTime scheduledAt = date!;
    try {
      final startStr = chosenSlot!.split(' - ')[0]; // '07:00'
      final h = int.parse(startStr.split(':')[0]);
      final m = int.parse(startStr.split(':')[1]);
      scheduledAt = DateTime(date!.year, date!.month, date!.day, h, m);
    } catch (_) {}

    try {
      // 2. Actualizar match_request a 'accepted'
      await FirebaseFirestore.instance
          .collection('match_requests').doc(docId)
          .update({'status': 'accepted', 'scheduledDate': dateStr,
                   'scheduledTimeSlot': chosenSlot});

      // 3. Crear scheduled_match
      final matchRef = await FirebaseFirestore.instance
          .collection('scheduled_matches').add({
        'player1Uid':      _uid,
        'player1Name':     _myName,
        'player2Uid':      fromUid,
        'player2Name':     fromName,
        'scheduledDate':   dateStr,
        'timeSlot':        chosenSlot,
        'scheduledAt':     Timestamp.fromDate(scheduledAt),
        'clubId':          widget.homeClubId,
        'status':          'scheduled',
        'reminder2hSent':  false,
        'reminder30mSent': false,
        'createdAt':       FieldValue.serverTimestamp(),
      });

      final matchId = matchRef.id;

      // 4. Escribir en my_reservations de ambos jugadores
      final reservaData1 = {
        'type':         'match',
        'opponentUid':  fromUid,
        'opponentName': fromName,
        'date':         dateStr,
        'timeSlot':     chosenSlot,
        'scheduledAt':  Timestamp.fromDate(scheduledAt),
        'clubId':       widget.homeClubId,
        'matchId':      matchId,
        'status':       'scheduled',
        'createdAt':    FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('my_reservations').add(reservaData1);

      await FirebaseFirestore.instance
          .collection('users').doc(fromUid)
          .collection('my_reservations').add({
        ...reservaData1,
        'opponentUid':  _uid,
        'opponentName': _myName,
      });

      // 5. Reservar cancha para ambos jugadores
      if (widget.homeClubId.isNotEmpty) {
        await _createMatchCourt(
          matchId:     matchId,
          clubId:      widget.homeClubId,
          dateStr:     dateStr,
          timeSlot:    chosenSlot!,
          scheduledAt: scheduledAt,
          player1Uid:  _uid,
          player1Name: _myName,
          player2Uid:  fromUid,
          player2Name: fromName,
        );
      }

      // 6. Notificar al que propuso
      await PushNotificationService.notifyMatchAccepted(
        toUid:    fromUid,
        fromName: _myName,
        date:     dateLbl,
        timeSlot: chosenSlot!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Partido agendado con $fromName · $dateLbl · $chosenSlot'),
          backgroundColor: const Color(0xFF1A4D32),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectInvitation({
    required String docId,
    required String fromUid,
    required String fromName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar invitación'),
        content: Text('¿Rechazás la propuesta de $fromName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RECHAZAR')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('match_requests').doc(docId)
          .update({'status': 'rejected'});
      await PushNotificationService.notifyMatchRejected(
        toUid:    fromUid,
        fromName: _myName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitación rechazada')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  // ── RESERVAR CANCHA AL CONFIRMAR PARTIDO ────────────────────────────────────
  Future<void> _createMatchCourt({
    required String matchId,
    required String clubId,
    required String dateStr,
    required String timeSlot,
    required DateTime scheduledAt,
    required String player1Uid,
    required String player1Name,
    required String player2Uid,
    required String player2Name,
  }) async {
    try {
      // Parsear franja "HH:mm - HH:mm" en slots de 30 min
      final parts = timeSlot.split(' - ');
      if (parts.length < 2) return;
      final startStr = parts[0].trim();
      final endStr   = parts[1].trim();

      int toMins(String t) {
        final sp = t.split(':');
        return int.parse(sp[0]) * 60 + int.parse(sp[1]);
      }
      String fromMins(int m) =>
          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

      final startMins = toMins(startStr);
      final endMins   = toMins(endStr);
      final slots30   = <String>[];
      for (var m = startMins; m < endMins; m += 30) slots30.add(fromMins(m));
      if (slots30.isEmpty) return;

      final db = FirebaseFirestore.instance;

      // Buscar primera cancha disponible
      final courts = await db.collection('clubs').doc(clubId)
          .collection('courts').get();

      String? availCourtId;
      String  availCourtName = 'Cancha';

      for (final court in courts.docs) {
        bool free = true;
        for (final slot in slots30) {
          final ex = await db
              .collection('clubs').doc(clubId)
              .collection('courts').doc(court.id)
              .collection('reservations')
              .where('date', isEqualTo: dateStr)
              .where('time', isEqualTo: slot)
              .limit(1)
              .get();
          if (ex.docs.isNotEmpty) { free = false; break; }
        }
        if (free) {
          availCourtId   = court.id;
          availCourtName = court.data()['courtName']?.toString() ?? 'Cancha';
          break;
        }
      }

      if (availCourtId == null) return; // sin cancha libre, el partido queda sin cancha asignada

      // Crear un slot por jugador en la cancha libre
      final batch = db.batch();
      for (final slot in slots30) {
        final slotEnd = fromMins(toMins(slot) + 30);
        for (final entry in [
          {'uid': player1Uid, 'name': player1Name},
          {'uid': player2Uid, 'name': player2Name},
        ]) {
          final ref = db.collection('clubs').doc(clubId)
              .collection('courts').doc(availCourtId)
              .collection('reservations').doc();
          batch.set(ref, {
            'playerId':       entry['uid'],
            'playerName':     entry['name'],
            'date':           dateStr,
            'time':           slot,
            'startRange':     startStr,
            'endRange':       endStr,
            'bookingGroupId': matchId,
            'matchId':        matchId,
            'paymentMethod':  'match',
            'amount':         0,
            'status':         'confirmado',
            'createdAt':      FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();

      // Actualizar scheduled_match con la cancha asignada
      await db.collection('scheduled_matches').doc(matchId).update({
        'courtId':   availCourtId,
        'courtName': availCourtName,
      });
    } catch (_) {}
  }

  // _loadOpponents reemplazado por StreamBuilder en _buildPlayerContent

  Future<void> _sendRequest(Player opponent) async {
    // Prevent duplicate invitations
    if (_pendingTo.contains(opponent.id)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya enviaste una invitación a este jugador')));
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('match_requests').add({
        'fromUid':   _uid,
        'toUid':     opponent.id,
        'fromName':  FirebaseAuth.instance.currentUser?.displayName ?? '',
        'toName':    opponent.displayName,
        'status':    'pending',
        'timeSlot':  _myTimeSlots.join(', '),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add to pending set
      setState(() => _pendingTo.add(opponent.id));

      // Notificar al rival por push
      await PushNotificationService.notifyMatchRequest(
        toUid:    opponent.id,
        fromName: FirebaseAuth.instance.currentUser?.displayName
            ?? 'Un jugador',
        timeSlot: _myTimeSlots.join(', '),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Solicitud enviada a ${opponent.displayName}'),
          backgroundColor: const Color(0xFF1A3A34),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  void _openWhatsApp(Player opponent) async {
    final msg = Uri.encodeComponent(
      'Hola ${opponent.displayName}! Te vi disponible en la app. '
      'Estoy libre ${_myTimeSlots.join(" / ")}. ¿Jugamos? Coordinamos dónde.',
    );
    final url = Uri.parse('https://wa.me/?text=$msg');
    try { await launchUrl(url,
        mode: LaunchMode.externalApplication); }
    catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
                onPressed: widget.onBack)
            : null,
        title: const Text('BUSCAR RIVAL',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // ── Disponibilidad siempre visible ──────────────────────
        _buildAvailabilityCard(),
        // ── Invitaciones pendientes ──────────────────────────────
        _buildInvitationsSection(),
        // ── Contenido de rivales ─────────────────────────────────
        Expanded(child: _buildPlayerContent()),
      ],
    );
  }

  Widget _buildInvitationsSection() {
    if (_uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('match_requests')
          .where('toUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.mail_outline,
                    color: Colors.orangeAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'INVITACIONES (${docs.length})',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
                ),
              ]),
              const SizedBox(height: 10),
              ...docs.map((d) {
                final data     = d.data() as Map<String, dynamic>;
                final fromName = data['fromName']?.toString() ?? 'Jugador';
                final fromUid  = data['fromUid']?.toString()  ?? '';
                final slot     = data['timeSlot']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fromName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        if (slot.isNotEmpty)
                          Text(slot,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                      ],
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _acceptInvitation(
                        docId:    d.id,
                        fromUid:  fromUid,
                        fromName: fromName,
                        timeSlot: slot,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ACEPTAR',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _rejectInvitation(
                        docId:    d.id,
                        fromUid:  fromUid,
                        fromName: fromName,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Text('NO',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerContent() {
    if (_loading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFCCFF00)),
          SizedBox(height: 16),
          Text('Cargando...', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]));
    }

    if (_error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.white38),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _init, child: const Text('REINTENTAR')),
        ]),
      ));
    }

    // ── Solo mostrar rivales si el usuario está disponible ───────────────────
    if (!_myAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: Colors.white.withOpacity(0.07), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Activá tu disponibilidad\npara ver rivales',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // ── Sin franjas seleccionadas → pedir que elija horario ──────────────────
    if (_myTimeSlots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule,
                  color: Colors.white.withOpacity(0.07), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Seleccioná al menos una franja\nhoraria para ver rivales',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // ── Lista de rivales en tiempo real ──────────────────────────────────────
    return StreamBuilder<QuerySnapshot>(
      stream: _myLevel.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('users')
              .where('status', isEqualTo: 'disponible')
              .where('tennisLevel', isEqualTo: _myLevel)
              .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
        }

        final clubList    = <_PlayerDist>[];
        final outsideList = <_PlayerDist>[];

        for (final doc in snap.data!.docs) {
          if (doc.id == _uid) continue;
          // Si este jugador YA me invitó, aparece en la sección de invitaciones — no duplicar aquí
          if (_receivedFrom.contains(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>;

          // Filtrar por franja horaria coincidente
          {
            final playerSlots = <String>{};
            final rawSlots = data['availableTimeSlots'];
            if (rawSlots is List) {
              playerSlots.addAll(rawSlots.map((e) => e.toString()));
            }
            final single = data['availableTimeSlot']?.toString() ?? '';
            if (single.isNotEmpty) {
              for (final s in single.split(',')) {
                final t = s.trim();
                if (t.isNotEmpty) playerSlots.add(t);
              }
            }
            // Si el jugador tiene franjas definidas y ninguna coincide con las mías → saltar
            if (playerSlots.isNotEmpty &&
                playerSlots.intersection(_myTimeSlots).isEmpty) continue;
          }
          final p = Player(
            id:                doc.id,
            displayName:       data['displayName']?.toString()       ?? 'Jugador',
            email:             data['email']?.toString()             ?? '',
            photoUrl:          data['photoURL']?.toString()          ?? '',
            eloRating:         (data['eloRating']    ?? 1000) as int,
            tennisLevel:       data['tennisLevel']?.toString()       ?? '',
            status:            'disponible',
            availableDate:     null,
            availableTimeSlot: data['availableTimeSlot']?.toString() ?? '',
            balance_coins:     (data['balance_coins'] ?? 0)     as int,
            role:              data['role']?.toString()              ?? 'player',
            location:          data['location'] as dynamic,
          );
          final playerClubId = data['homeClubId']?.toString()  ?? '';
          final clubName     = data['homeClubName']?.toString() ?? 'Otro club';
          double distKm = 99.0;
          if (_myPosition != null && data['location'] != null) {
            final loc = data['location'] as GeoPoint;
            distKm = Geolocator.distanceBetween(
              _myPosition!.latitude, _myPosition!.longitude,
              loc.latitude, loc.longitude,
            ) / 1000;
          }
          final entry = (player: p, distKm: distKm, clubName: clubName);
          if (playerClubId == widget.homeClubId && widget.homeClubId.isNotEmpty) {
            clubList.add(entry);
          } else {
            outsideList.add(entry);
          }
        }
        clubList.sort((a, b) => a.distKm.compareTo(b.distKm));
        outsideList.sort((a, b) => a.distKm.compareTo(b.distKm));

        if (clubList.isEmpty && outsideList.isEmpty) return _buildEmpty();

        return RefreshIndicator(
          color: const Color(0xFFCCFF00),
          backgroundColor: const Color(0xFF0A1F1A),
          onRefresh: () => _loadPending(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _sectionHeader(
                  'EN TU CLUB',
                  clubList.isNotEmpty
                      ? '${clubList.length} disponibles'
                      : 'Nadie disponible',
                  Colors.greenAccent, Icons.stadium)),

              if (clubList.isNotEmpty)
                SliverList(delegate: SliverChildBuilderDelegate(
                  (c, i) => _PlayerCard(
                      entry: clubList[i], isMyClub: true,
                      isPending: _pendingTo.contains(clubList[i].player.id),
                      onPropose: () => _sendRequest(clubList[i].player),
                      onWhatsApp: () => _openWhatsApp(clubList[i].player)),
                  childCount: clubList.length,
                ))
              else
                SliverToBoxAdapter(child: _noClubMsg()),

              // Expandir a otros clubes
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _showOutside = !_showOutside),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _showOutside
                          ? Colors.blueAccent.withOpacity(0.1)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _showOutside
                          ? Colors.blueAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(children: [
                      Icon(_showOutside ? Icons.keyboard_arrow_up : Icons.public,
                          color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showOutside ? 'Ocultar otros clubes' : 'Ampliar búsqueda a otros clubes',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            outsideList.isNotEmpty
                                ? '${outsideList.length} jugadores en otros clubes'
                                : 'Sin jugadores en otros clubes',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ])),
                      if (outsideList.isNotEmpty && !_showOutside)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('${outsideList.length}',
                              style: const TextStyle(color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ]),
                  ),
                ),
              )),

              if (_showOutside && outsideList.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionHeader(
                    'OTROS CLUBES', 'Coordiná fecha, hora y lugar',
                    Colors.blueAccent, Icons.public)),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.blueAccent, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Si acordás un partido con alguien de otro club, coordiná dónde juegan por WhatsApp.',
                        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4))),
                    ]),
                  ),
                )),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (c, i) => _PlayerCard(
                      entry: outsideList[i], isMyClub: false,
                      isPending: _pendingTo.contains(outsideList[i].player.id),
                      onPropose: () => _sendRequest(outsideList[i].player),
                      onWhatsApp: () => _openWhatsApp(outsideList[i].player)),
                  childCount: outsideList.length,
                )),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _myAvailable
                ? [
                    const Color(0xFFCCFF00).withOpacity(0.12),
                    const Color(0xFF0A3A2A),
                  ]
                : [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _myAvailable
                  ? const Color(0xFFCCFF00).withOpacity(0.3)
                  : Colors.white.withOpacity(0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle header
              Row(children: [
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _myAvailable
                        ? Colors.greenAccent : Colors.white24,
                    boxShadow: _myAvailable ? [
                      BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 8, spreadRadius: 1),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _myAvailable
                            ? 'DISPONIBLE PARA JUGAR'
                            : 'NO DISPONIBLE',
                        style: TextStyle(
                            color: _myAvailable
                                ? const Color(0xFFCCFF00)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      if (_myAvailable && _myTimeSlots.isNotEmpty)
                        Text(
                          _myTimeSlots.length == 1
                              ? _myTimeSlots.first
                              : '${_myTimeSlots.length} franjas',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                _availSaving
                    ? const SizedBox(width: 28, height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFCCFF00)))
                    : Switch(
                        value: _myAvailable,
                        activeColor: const Color(0xFFCCFF00),
                        activeTrackColor:
                            const Color(0xFFCCFF00).withOpacity(0.2),
                        inactiveThumbColor: Colors.white24,
                        inactiveTrackColor: Colors.white10,
                        onChanged: _setAvailability,
                      ),
              ]),

              if (_myAvailable) ...[
                const SizedBox(height: 14),
                const Text('¿EN QUÉ FRANJAS PODÉS JUGAR? (podés elegir varias)',
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                // Chip de acceso rápido: Hoy, todo el día
                Builder(builder: (ctx) {
                  final today = DateTime.now();
                  final isTodayAllDay = _availableForDate != null &&
                      _availableForDate!.year  == today.year &&
                      _availableForDate!.month == today.month &&
                      _availableForDate!.day   == today.day &&
                      _myTimeSlots.containsAll(_slots);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isTodayAllDay) {
                          _availableForDate = null;
                          _myTimeSlots.clear();
                        } else {
                          _availableForDate = today;
                          _myTimeSlots = Set.from(_slots);
                        }
                      });
                      if (_myAvailable) _setAvailability(true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isTodayAllDay
                            ? const Color(0xFFCCFF00)
                            : const Color(0xFFCCFF00).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTodayAllDay
                              ? const Color(0xFFCCFF00)
                              : const Color(0xFFCCFF00).withOpacity(0.25),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isTodayAllDay
                              ? Icons.check_circle
                              : Icons.wb_sunny_outlined,
                          color: isTodayAllDay
                              ? Colors.black : const Color(0xFFCCFF00),
                          size: 14,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'HOY, TODO EL DÍA',
                          style: TextStyle(
                            color: isTodayAllDay
                                ? Colors.black : const Color(0xFFCCFF00),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _slots.map((s) {
                    final sel = _myTimeSlots.contains(s);
                    return GestureDetector(
                      onTap: () => _toggleSlot(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFCCFF00)
                              : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFFCCFF00)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                color: sel ? Colors.black : Colors.white54,
                                fontSize: 11,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                // ── Fecha específica ──────────────────────────────
                const SizedBox(height: 12),
                const Text('¿PARA QUÉ FECHA?',
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickAvailableDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _availableForDate != null
                              ? const Color(0xFFCCFF00).withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _availableForDate != null
                                ? const Color(0xFFCCFF00).withOpacity(0.3)
                                : Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today,
                              color: _availableForDate != null
                                  ? const Color(0xFFCCFF00) : Colors.white24,
                              size: 13),
                          const SizedBox(width: 8),
                          Text(
                            _availableForDate == null
                                ? 'Cualquier día'
                                : DateFormat('EEEE d/MM', 'es')
                                    .format(_availableForDate!),
                            style: TextStyle(
                              color: _availableForDate != null
                                  ? const Color(0xFFCCFF00) : Colors.white38,
                              fontSize: 11,
                              fontWeight: _availableForDate != null
                                  ? FontWeight.bold : FontWeight.normal,
                            )),
                        ]),
                      ),
                    ),
                  ),
                  if (_availableForDate != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _clearAvailableDate,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 14),
                      ),
                    ),
                  ],
                ]),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Activá tu disponibilidad para que otros jugadores '
                  'de tu nivel puedan encontrarte.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.28),
                      fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String sub,
      Color color, IconData icon) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
        child: Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(
              color: color, fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1,
              color: color.withOpacity(0.15))),
          const SizedBox(width: 8),
          Text(sub, style: const TextStyle(
              color: Colors.white24, fontSize: 9)),
        ]),
      );

  Widget _noClubMsg() => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: Colors.white24, size: 16),
        SizedBox(width: 10),
        Expanded(child: Text(
          'Nadie de tu club está disponible ahora. '
          'Probá en otros clubes o activá tu disponibilidad '
          'para que te encuentren.',
          style: TextStyle(
              color: Colors.white38, fontSize: 11, height: 1.4),
        )),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
        const Text('🎾', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('No hay rivales disponibles',
            style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Activá tu disponibilidad arriba para que '
          'otros jugadores de tu nivel puedan encontrarte.',
          style: TextStyle(color: Colors.white38, fontSize: 12,
              height: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCFF00),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh, color: Colors.black),
          label: const Text('BUSCAR DE NUEVO',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          onPressed: _init,
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE JUGADOR
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerCard extends StatelessWidget {
  final _PlayerDist  entry;
  final bool         isMyClub;
  final bool         isPending;
  final VoidCallback onPropose;
  final VoidCallback onWhatsApp;
  const _PlayerCard({
    required this.entry,    required this.isMyClub,
    this.isPending = false,
    required this.onPropose, required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final p        = entry.player;
    final distKm   = entry.distKm;
    final clubName = entry.clubName;
    final photo    = p.photoUrl ?? '';
    final slot     = p.availableTimeSlot ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMyClub
                ? Colors.greenAccent.withOpacity(0.15)
                : Colors.blueAccent.withOpacity(0.1)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFF1A3A34),
          backgroundImage: photo.isNotEmpty
              ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? const Icon(Icons.person,
                  color: Colors.white38, size: 26) : null,
        ),
        const SizedBox(width: 12),

        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(p.displayName, style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(spacing: 5, runSpacing: 4, children: [
            _chip(p.tennisLevel, const Color(0xFFCCFF00)),
            if (!isMyClub)
              _chip(clubName, Colors.blueAccent),
            if (slot.isNotEmpty)
              _chip(slot, Colors.white38),
            if (distKm < 90)
              _chip(
                '${distKm < 1 ? "<1" : distKm.toStringAsFixed(1)} km',
                Colors.white24),
          ]),
        ])),
        const SizedBox(width: 8),

        Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPending
                  ? Colors.white24
                  : isMyClub ? const Color(0xFFCCFF00) : Colors.blueAccent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              minimumSize: Size.zero,
            ),
            onPressed: isPending ? null : onPropose,
            child: Text(
                isPending ? 'COORDINANDO' : (isMyClub ? 'PROPONER' : 'CONTACTAR'),
                style: TextStyle(
                    color: isPending ? Colors.white38 : (isMyClub ? Colors.black : Colors.white),
                    fontWeight: FontWeight.bold,
                    fontSize: 9)),
          ),
          if (!isMyClub) ...[
            const SizedBox(height: 5),
            GestureDetector(
              onTap: onWhatsApp,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.2)),
                ),
                child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.chat_outlined,
                      color: Colors.green, size: 11),
                  SizedBox(width: 3),
                  Text('WA', style: TextStyle(
                      color: Colors.green, fontSize: 8,
                      fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 8, fontWeight: FontWeight.bold)),
  );
}
