import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/tournament_model.dart';
import '../services/push_notification_service.dart';
import 'stats_calculator.dart';
import 'tournament_stats_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE DISEÑO
// ─────────────────────────────────────────────────────────────────────────────
const double kMatchW   = 240.0;
const double kMatchH   = 110.0;
const double kColGap   = 60.0;
const Color  kBg           = Color(0xFF0A0F1E);
const Color  kCardBg       = Color(0xFF12172B);
const Color  kYellow       = Color(0xFFE3FF00);
const Color  kWinnerBorder = Color(0xFF00FFCC);
const Color  kLineColor    = Color(0x55FFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE POSICIÓN DE MATCH
// ─────────────────────────────────────────────────────────────────────────────
class MatchPosition {
  final int    slotP1;
  final int    slotP2;
  final int    nextSlot;
  final double x;
  final double y;
  final bool   isLeft;
  final int    round;
  final bool   isFinal;

  const MatchPosition({
    required this.slotP1,
    required this.slotP2,
    required this.nextSlot,
    required this.x,
    required this.y,
    required this.isLeft,
    required this.round,
    this.isFinal = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CALCULADOR DE LAYOUT DEL BRACKET
// ─────────────────────────────────────────────────────────────────────────────
class BracketLayout {
  final int playerCount;
  late final int                 totalRounds;
  late final List<MatchPosition> matches;
  late final double              totalWidth;
  late final double              totalHeight;

  BracketLayout(this.playerCount) {
    totalRounds = (log(playerCount) / log(2)).round();
    _compute();
  }

  void _compute() {
    final positions = <MatchPosition>[];

    final int r0PerSide = (playerCount ~/ 4).clamp(1, 9999);
    totalHeight = 120 + (2 * r0PerSide - 1) * kMatchH * 1.15 + 120;

    final int sideCols = totalRounds - 1;
    totalWidth = sideCols * (kMatchW + kColGap) * 2 + kMatchW + kColGap * 2;

    final double finalX = (totalWidth - kMatchW) / 2;
    final double finalY = (totalHeight - kMatchH) / 2;

    for (int r = 0; r < totalRounds - 1; r++) {
      final int totalMatchesInRound = playerCount ~/ (pow(2, r + 1) as int);
      int matchesPerSide = totalMatchesInRound ~/ 2;
      if (matchesPerSide < 1) matchesPerSide = 1;

      final double spacing      = pow(2, r).toDouble() * kMatchH * 1.15;
      final double totalOccupied = (matchesPerSide - 1) * spacing + kMatchH;
      final double startY        = (totalHeight - totalOccupied) / 2;

      final int offset = _getOffset(r);

      final double xLeft  = r * (kMatchW + kColGap);
      final double xRight = totalWidth - kMatchW - r * (kMatchW + kColGap);

      for (int i = 0; i < matchesPerSide; i++) {
        final double matchY = startY + i * spacing;

        final int p1L   = offset + i * 2;
        final int p2L   = p1L + 1;
        final int nextL = _getNextSlot(p1L);
        positions.add(MatchPosition(
          slotP1: p1L, slotP2: p2L, nextSlot: nextL,
          x: xLeft, y: matchY, isLeft: true, round: r,
        ));

        final int p1R   = offset + totalMatchesInRound + i * 2;
        final int p2R   = p1R + 1;
        final int nextR = _getNextSlot(p1R);
        positions.add(MatchPosition(
          slotP1: p1R, slotP2: p2R, nextSlot: nextR,
          x: xRight, y: matchY, isLeft: false, round: r,
        ));
      }
    }

    final int finalOffset = _getOffset(totalRounds - 1);
    positions.add(MatchPosition(
      slotP1: finalOffset, slotP2: finalOffset + 1,
      nextSlot: -1, x: finalX, y: finalY,
      isLeft: true, round: totalRounds - 1, isFinal: true,
    ));

    matches = positions;
  }

  int _getOffset(int round) {
    int offset = 0, size = playerCount;
    for (int i = 0; i < round; i++) { offset += size; size ~/= 2; }
    return offset;
  }

  int _getNextSlot(int p1) {
    int offset = 0, size = playerCount;
    while (size > 2) {
      if (p1 >= offset && p1 < offset + size) {
        return offset + size + (p1 - offset) ~/ 2;
      }
      offset += size; size ~/= 2;
    }
    return -1;
  }

  MatchPosition? matchForSlot(int slotIndex) {
    for (final mp in matches) {
      if (mp.slotP1 == slotIndex || mp.slotP2 == slotIndex) return mp;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER DE LÍNEAS CONECTORAS
// ─────────────────────────────────────────────────────────────────────────────
class BracketLinesPainter extends CustomPainter {
  final BracketLayout                  layout;
  final Map<int, Map<String, dynamic>> slots;

  BracketLinesPainter({required this.layout, required this.slots});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = kLineColor
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final Map<int, MatchPosition> winnerSlotToFeeder = {};
    for (final mp in layout.matches) {
      if (mp.nextSlot != -1) winnerSlotToFeeder[mp.nextSlot] = mp;
    }

    for (final target in layout.matches) {
      if (target.round == 0 || target.isFinal) continue;

      final feeder1 = winnerSlotToFeeder[target.slotP1];
      final feeder2 = winnerSlotToFeeder[target.slotP2];
      if (feeder1 == null || feeder2 == null) continue;

      final double y1   = feeder1.y + kMatchH / 2;
      final double y2   = feeder2.y + kMatchH / 2;
      final double midY = (y1 + y2) / 2;

      final double connectorX, feeder1EdgeX, feeder2EdgeX, targetEdgeX;

      if (target.isLeft) {
        feeder1EdgeX = feeder1.x + kMatchW;
        feeder2EdgeX = feeder2.x + kMatchW;
        connectorX   = feeder1.x + kMatchW + kColGap * 0.5;
        targetEdgeX  = target.x;
      } else {
        feeder1EdgeX = feeder1.x;
        feeder2EdgeX = feeder2.x;
        connectorX   = feeder1.x - kColGap * 0.5;
        targetEdgeX  = target.x + kMatchW;
      }

      canvas.drawLine(Offset(feeder1EdgeX, y1), Offset(connectorX, y1), paint);
      canvas.drawLine(Offset(feeder2EdgeX, y2), Offset(connectorX, y2), paint);
      canvas.drawLine(Offset(connectorX, y1),   Offset(connectorX, y2), paint);
      canvas.drawLine(Offset(connectorX, midY), Offset(targetEdgeX, midY), paint);
    }

    final finalMatch = layout.matches.firstWhere((m) => m.isFinal);
    final semiRound  = layout.totalRounds - 2;

    for (final semi in layout.matches.where((m) => m.round == semiRound)) {
      final double semiY  = semi.y + kMatchH / 2;
      final double finalY = finalMatch.y + kMatchH / 2;

      if (semi.isLeft) {
        final double midX = semi.x + kMatchW + (finalMatch.x - semi.x - kMatchW) / 2;
        canvas.drawLine(Offset(semi.x + kMatchW, semiY), Offset(midX, semiY), paint);
        canvas.drawLine(Offset(midX, semiY),  Offset(midX, finalY),  paint);
        canvas.drawLine(Offset(midX, finalY), Offset(finalMatch.x, finalY), paint);
      } else {
        final double midX = finalMatch.x + kMatchW + (semi.x - finalMatch.x - kMatchW) / 2;
        canvas.drawLine(Offset(semi.x, semiY),  Offset(midX, semiY), paint);
        canvas.drawLine(Offset(midX, semiY),   Offset(midX, finalY),  paint);
        canvas.drawLine(Offset(midX, finalY),  Offset(finalMatch.x + kMatchW, finalY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(BracketLinesPainter old) => old.slots != slots;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class TournamentManagementScreen extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final String tournamentName;
  final int    playerCount;

  const TournamentManagementScreen({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentName,
    required this.playerCount,
  });

  @override
  State<TournamentManagementScreen> createState() =>
      _TournamentManagementScreenState();
}

class _TournamentManagementScreenState
    extends State<TournamentManagementScreen> {

  String _userRole          = 'player';
  String _tournamentStatus  = 'open'; // normalized status
  bool   _isLoading = true;
  late final BracketLayout _layout;
  RankingConfig _rankingConfig = const RankingConfig();
  String? _lastRecalculatedTournamentId;
  bool _isRankingConfigLoaded = false;

  // Plazos por ronda: round index → fecha límite
  Map<int, DateTime> _roundDeadlines = {};

  @override
  void initState() {
    super.initState();
    _layout = BracketLayout(_nearestValidCount(widget.playerCount));
    _loadUserRole();
    _loadRankingConfig();
    _loadRoundDeadlines();
  }

  int _nearestValidCount(int n) {
    for (final v in [4, 8, 16, 32]) { if (v >= n) return v; }
    return 32;
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    final futures = await Future.wait([
      if (user != null)
        FirebaseFirestore.instance.collection('users').doc(user.uid).get()
      else
        Future.value(null),
      FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get(),
    ]);

    if (mounted) setState(() {
      final userDoc = futures[0] as DocumentSnapshot?;
      _userRole = userDoc?.data() != null
          ? ((userDoc!.data() as Map<String, dynamic>)['role'] ?? 'player')
          : 'player';
      final tDoc = futures[1] as DocumentSnapshot;
      _tournamentStatus = normalizeTournamentStatus(
          (tDoc.data() as Map<String, dynamic>?)?['status']?.toString() ?? 'open');
      _isLoading = false;
    });
  }

  Future<void> _loadRankingConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    if (mounted) {
      final raw = doc.data()?['rankingConfig'];
      setState(() {
        _rankingConfig = RankingConfig.fromMap(
          raw is Map ? Map<String, dynamic>.from(raw) : null,
        );
        _isRankingConfigLoaded = true; // ADDED: Set flag to true after loading
      });
    }
  }

  Future<void> _loadRoundDeadlines() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final raw = doc.data()?['roundDeadlines'];
    if (raw is Map && mounted) {
      setState(() {
        _roundDeadlines = raw.map((k, v) =>
          MapEntry(int.tryParse(k.toString()) ?? 0,
            DateTime.tryParse(v.toString()) ?? DateTime.now()));
      });
    }
  }

  Future<void> _saveRoundDeadlines() async {
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .update({
      'roundDeadlines': _roundDeadlines.map(
          (k, v) => MapEntry(k.toString(), v.toIso8601String())),
    });
  }

  void _showDeadlineModal(int round) async {
    final label   = _roundLabel(round);
    final current = _roundDeadlines[round] ?? DateTime.now().add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Plazo para $label',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kYellow, surface: Color(0xFF1A3A34)),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _roundDeadlines[round] = picked);
      await _saveRoundDeadlines();
    }
  }

  // Notificar por WA a jugadores con partidos vencidos en una ronda
  Future<void> _notifyOverdueRound(
      int round, Map<int, Map<String, dynamic>> slots) async {
    int sent = 0;
    for (final mp in _layout.matches.where((m) => m.round == round)) {
      final s1 = slots[mp.slotP1];
      final s2 = slots[mp.slotP2];
      if (s1 == null || s2 == null) continue;
      final hasResult = (s1['score'] as List?)?.isNotEmpty == true;
      if (hasResult) continue;

      final n1     = s1['name']?.toString()  ?? '';
      final n2     = s2['name']?.toString()  ?? '';
      final phone1 = s1['phone']?.toString() ?? '';
      final phone2 = s2['phone']?.toString() ?? '';
      final dl     = _roundDeadlines[round];
      final dlStr  = dl != null ? DateFormat('dd/MM').format(dl) : 'ya';

      final msg = 'Hola! Tu partido de torneo contra {rival} '
          'debía jugarse antes del $dlStr. Por favor coordiná con tu rival. 🎾';

      Future<void> sendWA(String phone, String rival) async {
        if (phone.isEmpty) return;
        final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
        final url   = Uri.parse(
            'https://wa.me/549$clean?text=${Uri.encodeComponent(msg.replaceAll('{rival}', rival))}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          sent++;
        }
      }

      if (n1.isNotEmpty && n2.isNotEmpty) {
        await sendWA(phone1, n2);
        await sendWA(phone2, n1);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent > 0
            ? 'WhatsApp enviado a $sent jugador(es)'
            : 'No hay teléfonos cargados para notificar'),
        backgroundColor: sent > 0 ? Colors.greenAccent : Colors.orangeAccent,
      ));
    }
  }

  String _roundLabel(int r) {
    final diff = _layout.totalRounds - 1 - r;
    if (diff == 0) return 'GRAN FINAL';
    if (diff == 1) return 'SEMIFINAL';
    if (diff == 2) return 'CUARTOS';
    if (diff == 3) return 'OCTAVOS';
    return 'RONDA ${r + 1}';
  }

  bool get _isAdmin => _userRole == 'admin' || _userRole == 'coordinator';

  DocumentReference get _layoutDoc => FirebaseFirestore.instance
      .collection('tournaments')
      .doc(widget.tournamentId)
      .collection('temp_layout')
      .doc('current');

  Future<void> _persist(Map<int, Map<String, dynamic>> updated) =>
      _layoutDoc.set({
        'slots': updated.map((k, v) => MapEntry(k.toString(), v))
      });

  // ── GUARDAR RESULTADO ─────────────────────────────────────────────────────
  void _saveResult(
      int p1, int p2, int nextSlot,
      List<String> score, int winnerSlot,
      Map<int, Map<String, dynamic>> slots, {
      String? specialResult,
      int? woAbsentSlot,    // slot del ausente en W.O.
      int? abandonSlot,     // slot del que abandonó
      }) {
    final updated  = Map<int, Map<String, dynamic>>.from(slots);
    final loserSlot = winnerSlot == p1 ? p2 : p1;

    updated[p1] = {
      ...(slots[p1] ?? {}),
      'score':         score,
      'winner':        p1 == winnerSlot,
      'specialResult': specialResult ?? 'normal',
      // W.O.: marcar ausente solo en el que no se presentó
      'absent':   specialResult == 'walkover' && p1 == woAbsentSlot,
      // Abandono: marcar solo en el que abandonó
      'abandono': specialResult == 'abandono' && p1 == abandonSlot,
    };
    updated[p2] = {
      ...(slots[p2] ?? {}),
      'score':         score,
      'winner':        p2 == winnerSlot,
      'specialResult': specialResult ?? 'normal',
      'absent':   specialResult == 'walkover' && p2 == woAbsentSlot,
      'abandono': specialResult == 'abandono' && p2 == abandonSlot,
    };

    if (nextSlot != -1) {
      final w = updated[winnerSlot]!;
      updated[nextSlot] = {
        'name':          w['name']     ?? '',
        'phone':         w['phone']    ?? '',
        'photoUrl':      w['photoUrl'] ?? '',
        'uid':           w['uid']      ?? '',
        'score':         [],
        'winner':        false,
        'specialResult': 'normal',
        'absent':        false,
        'abandono':      false,
        'hadBye':        w['isBye'] == true || w['hadBye'] == true,
      };
    }
    _persist(updated).then((_) async {
      _triggerStatsRecalc(updated);

      // ── Write-through a matches subcollection (schema permanente) ──────────
      // Permite queries por ronda, historial de jugador, etc.
      try {
        final mp = _layout.matches.firstWhere(
          (m) => (m.slotP1 == p1 && m.slotP2 == p2) ||
                 (m.slotP1 == p2 && m.slotP2 == p1),
          orElse: () => _layout.matches.first,
        );
        // Solo persiste si encontramos el match correcto
        if ((mp.slotP1 == p1 && mp.slotP2 == p2) ||
            (mp.slotP1 == p2 && mp.slotP2 == p1)) {
          final roundLabel  = _roundLabel(mp.round);
          final p1uid       = updated[p1]?['uid']?.toString()         ?? '';
          final p2uid       = updated[p2]?['uid']?.toString()         ?? '';
          final p1name      = updated[p1]?['name']?.toString()        ?? '';
          final p2name      = updated[p2]?['name']?.toString()        ?? '';
          final winnerUid   = updated[winnerSlot]?['uid']?.toString() ?? '';
          final matchDocId  = 'r${mp.round}_s${mp.slotP1}_s${mp.slotP2}';

          await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('matches')
              .doc(matchDocId)
              .set({
            'tournamentId':   widget.tournamentId,
            'player1Id':      p1uid,
            'player1Name':    p1name,
            'player2Id':      p2uid,
            'player2Name':    p2name,
            'winnerId':       winnerUid,
            'score':          score,
            'round':          roundLabel,
            'status':         'played',
            'specialResult':  specialResult ?? 'normal',
            'slotP1':         mp.slotP1,
            'slotP2':         mp.slotP2,
            'isManualSync':   true,
            'updatedAt':      FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[Tournament] Write-through matches error: $e');
      }

      // Novedad automática
      final n1w = updated[winnerSlot]?['name'] ?? '';
      final nLose = updated[loserSlot]?['name'] ?? '';
      String msg;
      String type;
      if (specialResult == 'walkover') {
        msg  = '🎾 W.O. — $n1w avanzó, $nLose no se presentó';
        type = 'wo';
      } else if (specialResult == 'abandono') {
        msg  = '🚩 Abandono — $nLose abandonó vs $n1w';
        type = 'abandono';
      } else {
        msg  = '🎾 Resultado cargado: $n1w venció a $nLose';
        type = 'tournament';
      }
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('notifications').add({
        'type':         type,
        'message':      msg,
        'date':         DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time':         DateFormat('HH:mm').format(DateTime.now()),
        'sortKey':      DateFormat('yyyyMMddHHmm').format(DateTime.now()),
        'tournamentId': widget.tournamentId,
        'createdAt':    FieldValue.serverTimestamp(),
      });
      // Actualizar ELO (no bloquea: falla silenciosamente si no hay uid)
      _updateElo(winnerSlot, loserSlot, updated, specialResult);
      _awardMatchCoins(winnerSlot, updated, specialResult, nextSlot == -1);
    });
  }
  // ── ELO RATING UPDATE ─────────────────────────────────────────────────────
  /// Actualiza ELO de ganador y perdedor usando la fórmula estándar (K=32).
  /// Solo aplica si el slot tiene uid (jugadores inscriptos, no manuales).
  /// W.O. y BYE no modifican ELO.
  Future<void> _updateElo(
      int winnerSlot, int loserSlot,
      Map<int, Map<String, dynamic>> slots,
      String? specialResult) async {
    if (specialResult == 'walkover' || specialResult == 'bye') return;

    final winnerUid = slots[winnerSlot]?['uid']?.toString() ?? '';
    final loserUid  = slots[loserSlot]?['uid']?.toString()  ?? '';
    if (winnerUid.isEmpty || loserUid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final winDoc = await db.collection('users').doc(winnerUid).get();
      final losDoc = await db.collection('users').doc(loserUid).get();
      if (!winDoc.exists || !losDoc.exists) return;

      final winElo = ((winDoc.data()?['eloRating']) ?? 1000) as int;
      final losElo = ((losDoc.data()?['eloRating']) ?? 1000) as int;

      const k = 32.0;
      final eW = 1.0 / (1.0 + pow(10, (losElo - winElo) / 400.0));
      final eL = 1.0 - eW;

      final newWinElo = (winElo + k * (1 - eW)).round();
      final newLosElo = (losElo + k * (0 - eL)).round().clamp(100, 3000);

      await db.collection('users').doc(winnerUid).update({'eloRating': newWinElo});
      await db.collection('users').doc(loserUid).update({'eloRating': newLosElo});

      debugPrint('ELO actualizado: $winnerUid $winElo→$newWinElo | $loserUid $losElo→$newLosElo');
    } catch (e) {
      debugPrint('ELO update error: $e');
    }
  }

  /// Premia al ganador de un partido con coins.
  /// Si es el partido final (nextSlot == -1), también da el premio de campeón.
  Future<void> _awardMatchCoins(
      int winnerSlot, Map<int, Map<String, dynamic>> slots,
      String? specialResult, bool isFinal) async {
    if (specialResult == 'walkover' || specialResult == 'bye') return;

    final winnerUid = slots[winnerSlot]?['uid']?.toString() ?? '';
    if (winnerUid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;

      // Leer configuración del torneo
      final tDoc = await db.collection('tournaments').doc(widget.tournamentId).get();
      final coinsPerPartido = ((tDoc.data()?['coinsPerPartido']) ?? 50) as int;
      final premioCoins     = ((tDoc.data()?['premioCoins'])     ?? 0)  as int;

      int totalAward = coinsPerPartido;
      if (isFinal && premioCoins > 0) totalAward += premioCoins;

      if (totalAward <= 0) return;

      await db.collection('users').doc(winnerUid).update({
        'balance_coins': FieldValue.increment(totalAward),
      });

      // Log transacción
      final winnerName = slots[winnerSlot]?['name'] ?? 'Jugador';
      final desc = isFinal
          ? '🏆 Campeón del torneo + victoria: +$totalAward coins'
          : '🎾 Victoria en partido: +$coinsPerPartido coins';
      await db.collection('users').doc(winnerUid)
          .collection('coin_transactions').add({
        'amount':      totalAward,
        'type':        isFinal ? 'tournament_champion' : 'match_win',
        'description': desc,
        'createdAt':   FieldValue.serverTimestamp(),
        'date':        DateTime.now().toIso8601String(),
      });

      debugPrint('Coins premiadas: $winnerName +$totalAward (final: $isFinal)');
    } catch (e) {
      debugPrint('Error premiando coins: $e');
    }
  }

  /// Marca un slot vacío como BYE — el jugador del slot opuesto avanza automáticamente.
  void _assignBye(int emptySlot, Map<int, Map<String, dynamic>> slots) {
    final mp = _layout.matchForSlot(emptySlot);
    if (mp == null) return;

    final opponentSlot = mp.slotP1 == emptySlot ? mp.slotP2 : mp.slotP1;
    final opponent     = slots[opponentSlot];
    if (opponent == null || (opponent['name'] ?? '').toString().isEmpty) return;

    final updated = Map<int, Map<String, dynamic>>.from(slots);

    // Marcar el slot vacío como BYE
    updated[emptySlot] = {
      'name':   'BYE',
      'isBye':  true,
      'score':  [],
      'winner': false,
    };
    // El oponente avanza sin jugar
    updated[opponentSlot] = {
      ...opponent,
      'winner': true,
      'score':  ['BYE'],
      'specialResult': 'bye',
    };
    // Avanzar al ganador al siguiente slot
    if (mp.nextSlot != -1) {
      updated[mp.nextSlot] = {
        'name':          opponent['name']     ?? '',
        'phone':         opponent['phone']    ?? '',
        'photoUrl':      opponent['photoUrl'] ?? '',
        'uid':           opponent['uid']      ?? '',
        'score':         [],
        'winner':        false,
        'hadBye':        true,
        'specialResult': 'normal',
      };
    }
    _persist(updated).then((_) => _triggerStatsRecalc(updated));
  }

  Future<void> _triggerStatsRecalc(
      Map<int, Map<String, dynamic>> slots,
      ) async {
    final layoutInfo = BracketLayoutInfo(
      totalRounds: _layout.totalRounds,
      matches: _layout.matches.map((mp) => MatchInfo(
        slotP1:   mp.slotP1,
        slotP2:   mp.slotP2,
        nextSlot: mp.nextSlot,
        round:    mp.round,
        isFinal:  mp.isFinal,
      )).toList(),
    );
    await StatsCalculator.recalculate(
      tournamentId:  widget.tournamentId,
      slots:         slots,
      layoutInfo:    layoutInfo,
      rankingConfig: _rankingConfig,
    );
    if (mounted) {
      setState(() {
        _lastRecalculatedTournamentId = widget.tournamentId;
      });
    }
  }

  // ── ELIMINAR RESULTADO ────────────────────────────────────────────────────
  /// Borra el resultado del partido pero MANTIENE los jugadores en sus slots.
  /// Solo limpia scores, winner flags y specialResult.
  /// Si el ganador había avanzado al siguiente slot, lo limpia también.
  void _deleteResult(MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    final updated = Map<int, Map<String, dynamic>>.from(slots);

    // Limpiar resultado de P1 y P2 — pero conservar nombre, teléfono, foto
    updated[mp.slotP1] = {
      ...(slots[mp.slotP1] ?? {}),
      'score':         [],
      'winner':        false,
      'specialResult': 'normal',
      'absent':        false,
      'abandono':      false,
    };
    updated[mp.slotP2] = {
      ...(slots[mp.slotP2] ?? {}),
      'score':         [],
      'winner':        false,
      'specialResult': 'normal',
      'absent':        false,
      'abandono':      false,
    };

    // Al borrar un resultado, el ganador que había avanzado debe retroceder.
    // IMPORTANTE: solo se limpia el slot SIGUIENTE y en cascada hacia adelante.
    // Los nombres de P1 y P2 en este match se CONSERVAN — solo se borra el resultado.
    if (mp.nextSlot != -1) {
      final p1Name   = (slots[mp.slotP1]?['name'] ?? '').toString();
      final p2Name   = (slots[mp.slotP2]?['name'] ?? '').toString();
      final nextName = (slots[mp.nextSlot]?['name'] ?? '').toString();
      // Solo limpiar si el jugador del slot siguiente proviene de este match
      if (nextName.isNotEmpty &&
          (nextName == p1Name || nextName == p2Name)) {
        // Limpiar el slot siguiente — pero sin borrar el nombre si quedó por BYE
        final wasBye = slots[mp.nextSlot]?['hadBye'] == true;
        updated[mp.nextSlot] = {
          'name': '', 'phone': '', 'photoUrl': '',
          'score': [], 'winner': false, 'specialResult': 'normal',
          'absent': false, 'abandono': false,
        };
        // Cascada: limpiar slots más adelante donde el mismo jugador avanzó
        if (!wasBye) {
          _cascadeClearByName(updated, nextName, startSlot: mp.nextSlot);
        }
      }
    }

    _persist(updated).then((_) => _triggerStatsRecalc(updated));
  }

  // ── AGREGAR JUGADOR ───────────────────────────────────────────────────────
  void _addPlayer(int slotIndex, Map<int, Map<String, dynamic>> slots) {
    // Verificar si el slot opuesto tiene jugador — si sí, ofrecer BYE también
    final mp           = _layout.matchForSlot(slotIndex);
    final opponentSlot = mp == null
        ? null
        : (mp.slotP1 == slotIndex ? mp.slotP2 : mp.slotP1);
    final opponentName = opponentSlot != null
        ? (slots[opponentSlot]?['name'] ?? '').toString()
        : '';
    final canBye = opponentName.isNotEmpty && opponentName != 'BYE';

    showDialog(
      context: context,
      builder: (_) => _PlayerModal(
        title:   'AGREGAR JUGADOR',
        canBye:  canBye,
        onBye:   canBye
            ? () {
                Navigator.pop(context);
                _assignBye(slotIndex, slots);
              }
            : null,
        onSave: (name, phone) {
          final updated = Map<int, Map<String, dynamic>>.from(slots);
          updated[slotIndex] = {
            'name': name, 'phone': phone,
            'photoUrl': '', 'score': [], 'winner': false,
          };
          _persist(updated).then((_) => _triggerStatsRecalc(updated));
        },
      ),
    );
  }

  // ── EDITAR JUGADOR ────────────────────────────────────────────────────────
  void _editPlayer(
      int slotIndex,
      Map<String, dynamic> playerData,
      Map<int, Map<String, dynamic>> slots,
      ) {
    showDialog(
      context: context,
      builder: (_) => _PlayerModal(
        title:        'EDITAR JUGADOR',
        initialName:  playerData['name']  ?? '',
        initialPhone: playerData['phone'] ?? '',
        onSave: (newName, newPhone) {
          final oldName = (playerData['name'] ?? '').toString();
          final updated = Map<int, Map<String, dynamic>>.from(slots);

          updated[slotIndex] = {
            ...(updated[slotIndex] ?? {}),
            'name':  newName,
            'phone': newPhone,
          };

          if (oldName.isNotEmpty) {
            for (final key in updated.keys) {
              if (key == slotIndex) continue;
              if ((updated[key]?['name'] ?? '') == oldName) {
                updated[key] = {
                  ...(updated[key] ?? {}),
                  'name':  newName,
                  'phone': newPhone,
                };
              }
            }
          }
          _persist(updated).then((_) => _triggerStatsRecalc(updated)); // ADDED: Trigger recalc after editing player
        },
      ),
    );
  }

  // ── ELIMINAR JUGADOR ──────────────────────────────────────────────────────
  void _deletePlayer(int slotIndex, Map<int, Map<String, dynamic>> slots) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        message: '¿Eliminar al jugador y limpiar sus resultados?',
      ),
    );
    if (confirm != true) return;

    final updated    = Map<int, Map<String, dynamic>>.from(slots);
    final playerName = (updated[slotIndex]?['name'] ?? '').toString();

    _clearSlotAndMatch(updated, slotIndex);

    if (playerName.isNotEmpty) {
      _cascadeClearByName(updated, playerName, startSlot: slotIndex);
    }

    _persist(updated).then((_) => _triggerStatsRecalc(updated)); // ADDED: Trigger recalc after deleting player
  }

  void _clearSlotAndMatch(
      Map<int, Map<String, dynamic>> updated,
      int slotIndex,
      ) {
    updated[slotIndex] = {
      'name': '', 'phone': '', 'photoUrl': '', 'score': [], 'winner': false,
    };
    final mp = _layout.matchForSlot(slotIndex);
    if (mp != null) {
      updated[mp.slotP1] = {...(updated[mp.slotP1] ?? {}), 'score': [], 'winner': false};
      updated[mp.slotP2] = {...(updated[mp.slotP2] ?? {}), 'score': [], 'winner': false};
    }
  }

  void _cascadeClearByName(
      Map<int, Map<String, dynamic>> updated,
      String playerName, {
        int? startSlot,
      }) {
    if (playerName.isEmpty) return;

    final toClear = <int>[];
    for (final key in updated.keys) {
      if (key == startSlot) continue;
      if ((updated[key]?['name'] ?? '') == playerName) {
        toClear.add(key);
      }
    }

    for (final slotIndex in toClear) {
      _clearSlotAndMatch(updated, slotIndex);
    }
  }

  // ── ASIGNAR TURNO DE TORNEO A UNA CANCHA ─────────────────────────────────
  void _showAssignTurnModal(
      MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    final s1 = slots[mp.slotP1];
    final s2 = slots[mp.slotP2];
    final n1 = (s1?['name'] ?? '').toString();
    final n2 = (s2?['name'] ?? '').toString();
    if (n1.isEmpty || n2.isEmpty || n1 == 'BYE' || n2 == 'BYE') return;

    showDialog(
      context: context,
      builder: (_) => _AssignTurnModal(
        clubId:         widget.clubId,
        tournamentId:   widget.tournamentId,
        mp:             mp,
        slots:          slots,
        onAssigned: (date, time, courtId, courtName, {String? endTime}) async {
          // Guardar el turno en el slot del layout
          final updated = Map<int, Map<String, dynamic>>.from(slots);
          final slotData = {
            'date':       date,
            'time':       time,
            'endTime':    endTime ?? '',
            'courtId':    courtId,
            'courtName':  courtName,
          };
          updated[mp.slotP1] = {
            ...(slots[mp.slotP1] ?? {}),
            'matchSlot': slotData,
          };
          updated[mp.slotP2] = {
            ...(slots[mp.slotP2] ?? {}),
            'matchSlot': slotData,
          };
          await _persist(updated);

          // Novedad automática de turno asignado
          final endStr = endTime != null && endTime.isNotEmpty ? '–$endTime' : '';
          await FirebaseFirestore.instance
              .collection('clubs').doc(widget.clubId)
              .collection('notifications').add({
            'type':         'turno',
            'sortKey':      DateFormat('yyyyMMddHHmm').format(DateTime.now()),
            'message':      '📅 Turno asignado: $n1 vs $n2 · $courtName · $date $time$endStr',
            'date':         date,
            'time':         DateFormat('HH:mm').format(DateTime.now()),
            'tournamentId': widget.tournamentId,
            'createdAt':    FieldValue.serverTimestamp(),
          });

          // Mandar WhatsApp a ambos si tienen teléfono
          final phone1 = (s1?['phone'] ?? '').toString();
          final phone2 = (s2?['phone'] ?? '').toString();
          final msg = 'Hola! Tu partido de torneo contra '
              '{rival} está programado para el $date a las $time '
              'en $courtName. 🎾';
          if (phone1.isNotEmpty) {
            final clean1 = phone1.replaceAll(RegExp(r'[^\d]'), '');
            final m1 = msg.replaceAll('{rival}', n2);
            final url1 = Uri.parse(
                'https://wa.me/549$clean1?text=${Uri.encodeComponent(m1)}');
            if (await canLaunchUrl(url1)) {
              await launchUrl(url1, mode: LaunchMode.externalApplication);
            }
          }
          if (phone2.isNotEmpty) {
            final clean2 = phone2.replaceAll(RegExp(r'[^\d]'), '');
            final m2 = msg.replaceAll('{rival}', n1);
            final url2 = Uri.parse(
                'https://wa.me/549$clean2?text=${Uri.encodeComponent(m2)}');
            if (await canLaunchUrl(url2)) {
              await launchUrl(url2, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  // ── EDITAR SCORE ──────────────────────────────────────────────────────────
  void _editScore(MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    final s1 = slots[mp.slotP1];
    final s2 = slots[mp.slotP2];
    final n1 = (s1?['name'] ?? '').toString();
    final n2 = (s2?['name'] ?? '').toString();

    // Si uno está vacío, ofrecer BYE
    if ((n1.isEmpty || n1 == 'BYE') && n2.isNotEmpty && n2 != 'BYE') {
      _showByeDialog(mp.slotP1, mp, slots);
      return;
    }
    if ((n2.isEmpty || n2 == 'BYE') && n1.isNotEmpty && n1 != 'BYE') {
      _showByeDialog(mp.slotP2, mp, slots);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _ScoreModal(
        mp: mp, slots: slots,
        onSave:   _saveResult,
        onDelete: _deleteResult,
      ),
    );
  }

  void _showByeDialog(int emptySlot, MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    final opponentSlot = mp.slotP1 == emptySlot ? mp.slotP2 : mp.slotP1;
    final opponentName = slots[opponentSlot]?['name'] ?? 'el jugador';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1220),
        title: const Text('Slot vacío', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Text(
          '¿Asignás BYE? $opponentName avanzará automáticamente.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _assignBye(emptySlot, slots); },
            style: ElevatedButton.styleFrom(backgroundColor: kYellow),
            child: const Text('ASIGNAR BYE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Map<int, Map<String, dynamic>> _parseSlots(
      AsyncSnapshot<DocumentSnapshot> snap,
      ) {
    if (!snap.hasData || !snap.data!.exists) return {};
    final raw = (snap.data!.data() as Map<String, dynamic>)['slots'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(
      int.tryParse(k.toString()) ?? 0,
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kYellow)),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      // Banner de deadline vencida — solo visible para admin cuando el torneo
      // sigue "open" y la fecha de inscripción ya pasó.
      bottomNavigationBar: _isAdmin && _tournamentStatus == 'open'
          ? _DeadlineBanner(tournamentId: widget.tournamentId,
                            onDraw: _showDrawModal)
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _layoutDoc.snapshots(),
        builder: (context, snapshot) {
          final slots    = _parseSlots(snapshot);
          final screenW  = MediaQuery.of(context).size.width;
          final minScale = ((screenW - 40) / _layout.totalWidth).clamp(0.01, 1.0);

          // MODIFIED: Trigger stats recalculation when slots data and ranking config are available
          if (snapshot.hasData && snapshot.data!.exists && _isRankingConfigLoaded && _lastRecalculatedTournamentId != widget.tournamentId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerStatsRecalc(slots);
            });
          }

          return InteractiveViewer(
            minScale:        minScale,
            maxScale:        3.0,
            boundaryMargin:  const EdgeInsets.all(4000),
            constrained:     false,
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: _BracketCanvas(
                layout:           _layout,
                slots:            slots,
                isAdmin:          _isAdmin,
                onSave:           _saveResult,
                roundDeadlines:   _roundDeadlines,
                onAddPlayer:      _isAdmin ? (i)       => _addPlayer(i, slots)              : null,
                onEditPlayer:     _isAdmin ? (i, data) => _editPlayer(i, data, slots)       : null,
                onDeletePlayer:   _isAdmin ? (i)       => _deletePlayer(i, slots)           : null,
                onEditScore:      _isAdmin ? (mp)      => _editScore(mp, slots)             : null,
                onAssignTurn:     _isAdmin ? (mp)      => _showAssignTurnModal(mp, slots)   : null,
                onEditDeadline:   _isAdmin ? (r)       => _showDeadlineModal(r)             : null,
                onNotifyOverdue:  _isAdmin ? (r, s)    => _notifyOverdueRound(r, s)         : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── SORTEO DE JUGADORES ───────────────────────────────────────────────────
  Future<void> _showDrawModal() async {
    // Leer inscriptos del torneo
    final inscSnap = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('inscriptions')
        .get();

    if (!mounted) return;

    if (inscSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay jugadores inscriptos en este torneo.'),
        backgroundColor: Colors.orangeAccent,
      ));
      return;
    }

    final players = inscSnap.docs.map((d) {
      final data = d.data();
      return {
        'uid':         d.id,
        'name':        data['displayName']?.toString() ?? 'Jugador',
        'phone':       '',
        'photoUrl':    data['photoUrl']?.toString() ?? '',
      };
    }).toList();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1220),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DrawModal(
        players:      players,
        slotCount:    _layout.playerCount,
        onConfirm:    _applyDraw,
      ),
    );
  }

  Future<void> _applyDraw(List<Map<String, dynamic>> orderedPlayers) async {
    // Construir mapa de slots con los jugadores asignados
    final updated = <int, Map<String, dynamic>>{};
    for (int i = 0; i < orderedPlayers.length && i < _layout.playerCount; i++) {
      updated[i] = {
        'name':     orderedPlayers[i]['name']     ?? '',
        'phone':    orderedPlayers[i]['phone']    ?? '',
        'photoUrl': orderedPlayers[i]['photoUrl'] ?? '',
        'uid':      orderedPlayers[i]['uid']      ?? '',
        'score':    [],
        'winner':   false,
      };
    }

    await _persist(updated);

    // Actualizar estado del torneo a 'en_curso'
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .update({'status': 'en_curso'});

    // Notificar a cada jugador inscripto que el bracket está listo
    for (final player in orderedPlayers) {
      final uid = player['uid']?.toString() ?? '';
      if (uid.isEmpty) continue;
      PushNotificationService.sendToUser(
        toUid: uid,
        title: '🎾 ¡El sorteo está listo!',
        body:  'Tu primer partido en ${widget.tournamentName} ya está definido. Revisá el bracket.',
        type:  NotifType.matchSlot,
        extra: {'tournamentId': widget.tournamentId},
      );
    }

    if (mounted) {
      setState(() => _tournamentStatus = 'en_curso');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Sorteo realizado! El torneo está en curso.'),
        backgroundColor: Color(0xFF1A4D32),
      ));
    }
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.black,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.tournamentName.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
      Text('${_layout.playerCount} JUGADORES  •  ${_layout.totalRounds} RONDAS',
          style: TextStyle(color: kYellow.withAlpha(179),
              fontSize: 9, letterSpacing: 1.5)),
    ]),
    actions: [
      // Botón de sorteo — solo visible para admin cuando el torneo está abierto
      if (_isAdmin && _tournamentStatus == 'open')
        IconButton(
          icon: const Icon(Icons.shuffle_rounded, color: kYellow, size: 22),
          tooltip: 'Generar sorteo',
          onPressed: _showDrawModal,
        ),
      // Botón de estadísticas
      IconButton(
        icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 20),
        tooltip: 'Estadísticas',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentStatsScreen(
              clubId:         widget.clubId,
              tournamentId:   widget.tournamentId,
              tournamentName: widget.tournamentName,
              isAdmin:        _isAdmin,
              rankingConfig:  _rankingConfig,
              onConfigSaved: (newCfg) {
                setState(() => _rankingConfig = newCfg);
                FirebaseFirestore.instance
                    .collection('tournaments')
                    .doc(widget.tournamentId)
                    .update({'rankingConfig': newCfg.toMap()});
              },
            ),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: kYellow.withAlpha(102)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(_isAdmin ? Icons.shield : Icons.visibility,
              color: _isAdmin ? kYellow : Colors.white38, size: 11),
          const SizedBox(width: 4),
          Text(_isAdmin ? 'ADMIN' : 'VIEWER',
              style: TextStyle(color: _isAdmin ? kYellow : Colors.white38,
                  fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER DEADLINE VENCIDA
// ─────────────────────────────────────────────────────────────────────────────
/// Muestra un banner en la parte inferior cuando la fecha de inscripción venció
/// y el torneo todavía está en estado 'open'. Sugiere generar el sorteo.
class _DeadlineBanner extends StatelessWidget {
  final String      tournamentId;
  final VoidCallback onDraw;

  const _DeadlineBanner({
    required this.tournamentId,
    required this.onDraw,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .get(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data     = snap.data!.data() as Map<String, dynamic>? ?? {};
        final dlTs     = data['inscriptionDeadline'] as Timestamp?;
        if (dlTs == null) return const SizedBox.shrink();
        final deadline = dlTs.toDate();
        if (!deadline.isBefore(DateTime.now())) return const SizedBox.shrink();

        // Deadline pasó — mostrar banner
        return Container(
          color: const Color(0xFF0A0F1E),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.timer_off_rounded,
                    color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'La inscripción venció. ¿Generás el bracket ahora?',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: onDraw,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('SORTEAR',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRACKET CANVAS
// ─────────────────────────────────────────────────────────────────────────────
class _BracketCanvas extends StatelessWidget {
  final BracketLayout                  layout;
  final Map<int, Map<String, dynamic>> slots;
  final bool                           isAdmin;
  final Map<int, DateTime>             roundDeadlines;
  final Function(int, int, int, List<String>, int, Map<int, Map<String, dynamic>>) onSave;
  final Function(int)?                       onAddPlayer;
  final Function(int, Map<String, dynamic>)? onEditPlayer;
  final Function(int)?                       onDeletePlayer;
  final Function(MatchPosition)?             onEditScore;
  final Function(MatchPosition)?             onAssignTurn;
  final Function(int round)?                 onEditDeadline;
  final Function(int round, Map<int, Map<String, dynamic>> slots)? onNotifyOverdue;

  const _BracketCanvas({
    required this.layout,
    required this.slots,
    required this.isAdmin,
    required this.onSave,
    this.roundDeadlines = const {},
    this.onAddPlayer,
    this.onEditPlayer,
    this.onDeletePlayer,
    this.onEditScore,
    this.onAssignTurn,
    this.onEditDeadline,
    this.onNotifyOverdue,
  });

  String _roundLabel(int r) {
    final diff = layout.totalRounds - 1 - r;
    if (diff == 0) return 'GRAN FINAL';
    if (diff == 1) return 'SEMIFINAL';
    if (diff == 2) return 'CUARTOS';
    if (diff == 3) return 'OCTAVOS';
    return 'RONDA ${r + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> addedLabels = {};

    return SizedBox(
      width:  layout.totalWidth,
      height: layout.totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _BgGridPainter())),
          Positioned.fill(child: CustomPaint(
              painter: BracketLinesPainter(layout: layout, slots: slots))),

          for (final mp in layout.matches) ...[

            if (!mp.isFinal)
              Builder(builder: (_) {
                final key = '${mp.round}_${mp.isLeft}';
                if (addedLabels.contains(key)) return const SizedBox.shrink();
                addedLabels.add(key);

                final deadline = roundDeadlines[mp.round];
                final now      = DateTime.now();
                Color dlColor  = Colors.white38;
                String dlText  = '';
                bool   overdue = false;

                if (deadline != null) {
                  final daysLeft = deadline.difference(
                      DateTime(now.year, now.month, now.day)).inDays;
                  overdue = daysLeft < 0;
                  if (overdue) {
                    dlColor = Colors.redAccent;
                    dlText  = 'VENCIÓ ${DateFormat('dd/MM').format(deadline)}';
                  } else if (daysLeft <= 2) {
                    dlColor = Colors.orangeAccent;
                    dlText  = 'VENCE ${DateFormat('dd/MM').format(deadline)}';
                  } else {
                    dlColor = Colors.white38;
                    dlText  = DateFormat('dd/MM').format(deadline);
                  }
                }

                return Positioned(
                  left: mp.x, top: mp.y - (deadline != null ? 38 : 22),
                  width: kMatchW,
                  child: GestureDetector(
                    onTap: isAdmin ? () => onEditDeadline?.call(mp.round) : null,
                    onLongPress: (isAdmin && overdue)
                        ? () => onNotifyOverdue?.call(mp.round, slots)
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label de ronda
                        Text(_roundLabel(mp.round),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF2E4270),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.5)),

                        // Deadline
                        if (deadline != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                overdue
                                    ? Icons.warning_amber_rounded
                                    : Icons.schedule,
                                color: dlColor,
                                size: 8,
                              ),
                              const SizedBox(width: 3),
                              Text(dlText,
                                  style: TextStyle(
                                      color: dlColor,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold)),
                              if (isAdmin) ...[
                                const SizedBox(width: 3),
                                Icon(Icons.edit,
                                    color: dlColor.withAlpha(100), size: 7),
                              ],
                            ],
                          ),
                        ] else if (isAdmin) ...[
                          const SizedBox(height: 2),
                          Text('+ PLAZO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withAlpha(30),
                                  fontSize: 7,
                                  letterSpacing: 1)),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            if (mp.isFinal)
              Positioned(
                left: mp.x, top: mp.y - 54, width: kMatchW,
                child: const Column(children: [
                  Icon(Icons.emoji_events, color: kYellow, size: 22),
                  SizedBox(height: 2),
                  Text('GRAN FINAL', textAlign: TextAlign.center,
                      style: TextStyle(color: kYellow, fontSize: 9,
                          fontWeight: FontWeight.bold, letterSpacing: 3)),
                ]),
              ),

            Positioned(
              left: mp.x, top: mp.y, width: kMatchW, height: kMatchH,
              child: _MatchBox(
                mp:             mp,
                slots:          slots,
                isAdmin:        isAdmin,
                onAddPlayer:    onAddPlayer,
                onEditPlayer:   onEditPlayer,
                onDeletePlayer: onDeletePlayer,
                onEditScore:    onEditScore,
                onAssignTurn:   onAssignTurn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCH BOX
// ─────────────────────────────────────────────────────────────────────────────
class _MatchBox extends StatelessWidget {
  final MatchPosition                  mp;
  final Map<int, Map<String, dynamic>> slots;
  final bool                           isAdmin;
  final Function(int)?                       onAddPlayer;
  final Function(int, Map<String, dynamic>)? onEditPlayer;
  final Function(int)?                       onDeletePlayer;
  final Function(MatchPosition)?             onEditScore;
  final Function(MatchPosition)?             onAssignTurn;

  const _MatchBox({
    required this.mp,
    required this.slots,
    required this.isAdmin,
    this.onAddPlayer,
    this.onEditPlayer,
    this.onDeletePlayer,
    this.onEditScore,
    this.onAssignTurn,
  });

  @override
  Widget build(BuildContext context) {
    // Leer turno asignado desde cualquiera de los dos slots
    final matchSlot = slots[mp.slotP1]?['matchSlot'] as Map?
        ?? slots[mp.slotP2]?['matchSlot'] as Map?;
    final hasSlot    = matchSlot != null;
    final slotDate   = hasSlot ? matchSlot['date']?.toString()     ?? '' : '';
    final slotTime   = hasSlot ? matchSlot['time']?.toString()     ?? '' : '';
    final slotEnd    = hasSlot ? matchSlot['endTime']?.toString()  ?? '' : '';
    final slotCourt  = hasSlot ? matchSlot['courtName']?.toString() ?? '' : '';
    final slotLabel  = slotEnd.isNotEmpty
        ? '$slotDate · $slotTime–$slotEnd · $slotCourt'
        : '$slotDate · $slotTime · $slotCourt';

    // Hay resultado ya cargado
    final hasResult = (slots[mp.slotP1]?['score'] as List?)?.isNotEmpty == true;

    // Ambos jugadores presentes (no BYE, no vacío)
    final n1 = (slots[mp.slotP1]?['name'] ?? '').toString();
    final n2 = (slots[mp.slotP2]?['name'] ?? '').toString();
    final bothPresent = n1.isNotEmpty && n2.isNotEmpty &&
        n1 != 'BYE' && n2 != 'BYE';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card principal del partido
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: mp.isFinal
                    ? kYellow.withAlpha(89)
                    : Colors.white.withAlpha(18),
                width: mp.isFinal ? 1.5 : 1,
              ),
              boxShadow: mp.isFinal
                  ? [BoxShadow(color: kYellow.withAlpha(15),
                      blurRadius: 24, spreadRadius: 4)]
                  : null,
            ),
            child: Column(children: [
              Expanded(child: _PlayerRow(
                data: slots[mp.slotP1], opponent: slots[mp.slotP2],
                isP1: true, isTopRow: true,
                slotIndex: mp.slotP1, mp: mp, isAdmin: isAdmin,
                onAddPlayer: onAddPlayer, onEditPlayer: onEditPlayer,
                onDeletePlayer: onDeletePlayer, onEditScore: onEditScore,
              )),
              Container(height: 1, color: Colors.white.withAlpha(13)),
              Expanded(child: _PlayerRow(
                data: slots[mp.slotP2], opponent: slots[mp.slotP1],
                isP1: false, isTopRow: false,
                slotIndex: mp.slotP2, mp: mp, isAdmin: isAdmin,
                onAddPlayer: onAddPlayer, onEditPlayer: onEditPlayer,
                onDeletePlayer: onDeletePlayer, onEditScore: onEditScore,
              )),
            ]),
          ),
        ),

        // ── TURNO ASIGNADO o BOTÓN ASIGNAR ──────────────────────────────────
        if (bothPresent && !hasResult && isAdmin) ...[
          const SizedBox(height: 4),
          if (hasSlot)
            // Mostrar turno ya asignado — tappable para cambiar
            GestureDetector(
              onTap: () => onAssignTurn?.call(mp),
              child: Container(
                width: kMatchW,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kYellow.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kYellow.withAlpha(50)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule,
                      color: kYellow, size: 10),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      slotLabel,
                      style: const TextStyle(
                          color: kYellow,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit,
                      color: kYellow, size: 8),
                ]),
              ),
            )
          else
            // Botón para asignar turno
            GestureDetector(
              onTap: () => onAssignTurn?.call(mp),
              child: Container(
                width: kMatchW,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.white24, size: 10),
                    SizedBox(width: 4),
                    Text('ASIGNAR TURNO',
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER ROW
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerRow extends StatelessWidget {
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? opponent;
  final bool                  isP1;
  final bool                  isTopRow;
  final int                   slotIndex;
  final MatchPosition         mp;
  final bool                  isAdmin;
  final Function(int)?                       onAddPlayer;
  final Function(int, Map<String, dynamic>)? onEditPlayer;
  final Function(int)?                       onDeletePlayer;
  final Function(MatchPosition)?             onEditScore;

  const _PlayerRow({
    this.data, this.opponent,
    required this.isP1, required this.isTopRow,
    required this.slotIndex, required this.mp, required this.isAdmin,
    this.onAddPlayer, this.onEditPlayer,
    this.onDeletePlayer, this.onEditScore,
  });

  bool   get _hasPlayer  => data != null && (data!['name'] ?? '').toString().isNotEmpty && data!['name'] != 'BYE';
  String get _name       => _hasPlayer ? (data!['name'] as String).toUpperCase() : '';
  bool   get _isWinner   => data?['winner'] == true;
  bool   get _isBye      => data?['isBye'] == true || data?['name'] == 'BYE';

  @override
  Widget build(BuildContext context) {
    final String? phone = data?['phone'];
    final String? photo = data?['photoUrl'];
    final List    score = (data?['score'] as List?) ?? [];

    final br = isTopRow
        ? const BorderRadius.only(
        topLeft: Radius.circular(5), topRight: Radius.circular(5))
        : const BorderRadius.only(
        bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: br,
        color:  _isWinner ? kWinnerBorder.withAlpha(15) : Colors.transparent,
        border: Border(left: BorderSide(
            color: _isWinner ? kWinnerBorder : Colors.transparent, width: 3)),
      ),
      child: Row(children: [

        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(10),
            image: (photo != null && photo.isNotEmpty)
                ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
                : null,
          ),
          child: (photo == null || photo.isEmpty)
              ? Icon(Icons.person, size: 12, color: Colors.white.withAlpha(38))
              : null,
        ),
        const SizedBox(width: 5),

        Expanded(child: _buildName()),

        if (isAdmin && _hasPlayer && mp.round == 0 && onDeletePlayer != null)
          GestureDetector(
            onTap: () => onDeletePlayer!(slotIndex),
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(Icons.delete_outline,
                  color: Colors.redAccent.withAlpha(160), size: 13),
            ),
          ),

        if (phone != null && phone.isNotEmpty)
          GestureDetector(
            onTap: () => _launchWA(phone, _name, opponent?['name']?.toString()),
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(Icons.message_rounded,
                  color: Colors.greenAccent.withAlpha(166), size: 13),
            ),
          ),

        GestureDetector(
          onTap: isAdmin && onEditScore != null ? () => onEditScore!(mp) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              String val = '-';
              if (score.length > i) {
                final parts = score[i].toString().split('-');
                if (parts.length == 2) val = isP1 ? parts[0] : parts[1];
              }
              return _ScoreCell(
                  value: val, highlight: _isWinner && val != '-');
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildName() {
    // BYE
    if (_isBye) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('BYE', style: TextStyle(
            color: Colors.white38, fontSize: 9,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
      );
    }

    // Badge correcto:
    // W.O. → solo en el ausente (absent == true)
    // ABD  → solo en el que abandonó (abandono == true)
    Widget? badge;
    final isAbsent   = data?['absent']   == true;
    final isAbandono = data?['abandono'] == true;

    if (isAbsent) {
      badge = _specialBadge('W.O.', Colors.orangeAccent);
    } else if (isAbandono) {
      badge = _specialBadge('ABD', Colors.redAccent);
    }

    final nameWidget = _hasPlayer
        ? (isAdmin
            ? GestureDetector(
                onTap: () => onEditPlayer?.call(slotIndex, data!),
                child: Text(_name,
                  style: TextStyle(
                    color: _isWinner ? Colors.white : Colors.white70,
                    fontSize: 10, letterSpacing: 0.3,
                    fontWeight: _isWinner ? FontWeight.bold : FontWeight.normal,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white24,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                _hasPlayer ? _name : 'ESPERANDO...',
                style: TextStyle(
                  color: _hasPlayer ? (_isWinner ? Colors.white : Colors.white60) : Colors.white.withAlpha(51),
                  fontSize: 10, letterSpacing: 0.3,
                  fontWeight: _isWinner ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ))
        : (mp.round == 0 && isAdmin
            ? GestureDetector(
                onTap: () => onAddPlayer?.call(slotIndex),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_circle_outline, color: Colors.white38, size: 13),
                  const SizedBox(width: 3),
                  const Text('AGREGAR', style: TextStyle(color: Colors.white38, fontSize: 9)),
                ]),
              )
            : Text('ESPERANDO...', style: TextStyle(color: Colors.white.withAlpha(51), fontSize: 10)));

    if (badge == null) return nameWidget;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: nameWidget),
      const SizedBox(width: 5),
      badge,
    ]);
  }

  Widget _specialBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 8,
          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Future<void> _launchWA(String phone, String name, String? rival) async {
    final clean = phone.replaceAll(RegExp(r'[+\s\-]'), '');
    final msg   = 'Hola $name! Tu próximo partido es contra '
        '${rival ?? 'un oponente por definir'}. ¡Suerte! 🎾';
    final url = Uri.parse(
        'https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCORE CELL
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreCell extends StatelessWidget {
  final String value;
  final bool   highlight;
  const _ScoreCell({required this.value, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: highlight ? kYellow.withAlpha(31) : Colors.black.withAlpha(89),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: value != '-' ? Colors.white.withAlpha(20) : Colors.transparent,
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(value,
          style: TextStyle(
            color: value != '-'
                ? (highlight ? kYellow : Colors.white70)
                : Colors.white.withAlpha(51),
            fontWeight: FontWeight.bold, fontSize: 9,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE SCORE
// ─────────────────────────────────────────────────────────────────────────────
// Tipos especiales de resultado
enum SpecialResult { none, walkover, abandono }

class _ScoreModal extends StatefulWidget {
  final MatchPosition                  mp;
  final Map<int, Map<String, dynamic>> slots;
  final Function(int, int, int, List<String>, int, Map<int, Map<String, dynamic>>,
      {String? specialResult, int? woAbsentSlot, int? abandonSlot}) onSave;
  final Function(MatchPosition, Map<int, Map<String, dynamic>>) onDelete;

  const _ScoreModal({
    required this.mp, required this.slots,
    required this.onSave, required this.onDelete,
  });

  @override
  State<_ScoreModal> createState() => _ScoreModalState();
}

class _ScoreModalState extends State<_ScoreModal> {
  late final List<TextEditingController> _c1, _c2;
  SpecialResult _specialResult = SpecialResult.none;

  String get _n1 =>
      (widget.slots[widget.mp.slotP1]?['name'] ?? 'Jugador 1').toString();
  String get _n2 =>
      (widget.slots[widget.mp.slotP2]?['name'] ?? 'Jugador 2').toString();

  @override
  void initState() {
    super.initState();
    _c1 = List.generate(3, (_) => TextEditingController());
    _c2 = List.generate(3, (_) => TextEditingController());
    final existing =
        (widget.slots[widget.mp.slotP1]?['score'] as List?) ?? [];
    for (int i = 0; i < min(existing.length, 3); i++) {
      final parts = existing[i].toString().split('-');
      if (parts.length == 2) {
        _c1[i].text = parts[0];
        _c2[i].text = parts[1];
      }
    }
  }

  @override
  void dispose() {
    for (final c in [..._c1, ..._c2]) c.dispose();
    super.dispose();
  }

  int _winnerFromScore() {
    int s1 = 0, s2 = 0;
    for (int i = 0; i < 3; i++) {
      final v1 = int.tryParse(_c1[i].text) ?? 0;
      final v2 = int.tryParse(_c2[i].text) ?? 0;
      if (i < 2) {
        if (v1 > v2) s1++; else if (v2 > v1) s2++;
      } else if (s1 == 1 && s2 == 1) {
        if (v1 > v2) s1++; else s2++;
      }
    }
    return s1 > s2 ? widget.mp.slotP1 : widget.mp.slotP2;
  }

  void _save() {
    final scores = List.generate(3, (i) =>
        '${_c1[i].text.isEmpty ? '0' : _c1[i].text}'
        '-${_c2[i].text.isEmpty ? '0' : _c2[i].text}');

    switch (_specialResult) {
      case SpecialResult.none:
        widget.onSave(
          widget.mp.slotP1, widget.mp.slotP2,
          widget.mp.nextSlot, scores, _winnerFromScore(), widget.slots,
        );
        Navigator.pop(context);
        break;
      case SpecialResult.walkover:
        // Preguntamos quién NO se presentó
        _showWOPicker(scores);
        break;
      case SpecialResult.abandono:
        // Preguntamos quién abandonó
        _showAbandonoPicker(scores);
        break;
    }
  }

  /// W.O. — elegir el AUSENTE. El ganador es el otro automáticamente.
  void _showWOPicker(List<String> scores) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1220),
        title: const Text('¿Quién NO se presentó?',
            style: TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.bold)),
        content: Text(
          'El jugador ausente queda con badge W.O.\nEl otro avanza automáticamente.',
          style: TextStyle(color: Colors.orangeAccent.withAlpha(180),
              fontSize: 11, height: 1.5),
        ),
        actions: [
          // P1 es el ausente → P2 gana
          TextButton(
            onPressed: () {
              Navigator.pop(context); // cerrar picker
              Navigator.pop(context); // cerrar modal score
              widget.onSave(
                widget.mp.slotP1, widget.mp.slotP2,
                widget.mp.nextSlot, scores,
                widget.mp.slotP2, // ganador = P2
                widget.slots,
                specialResult: 'walkover',
                woAbsentSlot: widget.mp.slotP1, // ausente = P1
              );
            },
            child: Text(_n1.toUpperCase(),
                style: const TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
          // P2 es el ausente → P1 gana
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onSave(
                widget.mp.slotP1, widget.mp.slotP2,
                widget.mp.nextSlot, scores,
                widget.mp.slotP1, // ganador = P1
                widget.slots,
                specialResult: 'walkover',
                woAbsentSlot: widget.mp.slotP2, // ausente = P2
              );
            },
            child: Text(_n2.toUpperCase(),
                style: const TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// ABANDONO — elegir quién abandonó. El ganador es el otro.
  /// El score queda como estaba (parcial), las stats se completan en el calculator.
  void _showAbandonoPicker(List<String> scores) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1220),
        title: const Text('¿Quién abandonó?',
            style: TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.bold)),
        content: Text(
          'El score queda como quedó.\nLas estadísticas se completan a favor del ganador.',
          style: TextStyle(color: Colors.redAccent.withAlpha(180),
              fontSize: 11, height: 1.5),
        ),
        actions: [
          // P1 abandonó → P2 gana
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onSave(
                widget.mp.slotP1, widget.mp.slotP2,
                widget.mp.nextSlot, scores,
                widget.mp.slotP2, // ganador = P2
                widget.slots,
                specialResult: 'abandono',
                abandonSlot: widget.mp.slotP1, // abandonó P1
              );
            },
            child: Text(_n1.toUpperCase(),
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          // P2 abandonó → P1 gana
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onSave(
                widget.mp.slotP1, widget.mp.slotP2,
                widget.mp.nextSlot, scores,
                widget.mp.slotP1, // ganador = P1
                widget.slots,
                specialResult: 'abandono',
                abandonSlot: widget.mp.slotP2, // abandonó P2
              );
            },
            child: Text(_n2.toUpperCase(),
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kYellow.withAlpha(51)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(179),
                blurRadius: 40, spreadRadius: 8)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _header('CARGAR RESULTADO', Icons.sports_tennis),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // Tipo de resultado especial
                _buildSpecialResultToggle(),
                const SizedBox(height: 16),

                // Score (solo visible si no es W.O. puro)
                if (_specialResult != SpecialResult.walkover) ...[
                  Row(children: [
                    const Expanded(child: SizedBox()),
                    ...['SET 1', 'SET 2', 'SET 3'].map((s) => SizedBox(width: 50,
                        child: Center(child: Text(s, style: const TextStyle(
                            color: Color(0xFF3A5080), fontSize: 8,
                            letterSpacing: 1.5, fontWeight: FontWeight.bold))))),
                  ]),
                  const SizedBox(height: 12),
                  _inputRow(_n1, _c1),
                  const SizedBox(height: 6),
                  _vsDivider(),
                  const SizedBox(height: 6),
                  _inputRow(_n2, _c2),
                ] else ...[
                  // W.O.: solo mostrar los nombres
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withAlpha(40)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'El rival no se presentó. Al guardar elegís quién ganó. El ganador suma PJ pero no %G.',
                        style: TextStyle(color: Colors.orangeAccent.withAlpha(200),
                            fontSize: 10, height: 1.4),
                      )),
                    ]),
                  ),
                ],

                // Info de abandono
                if (_specialResult == SpecialResult.abandono) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(40)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.exit_to_app,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Cargá el score como quedó. Al guardar te preguntará quién abandonó.',
                        style: TextStyle(color: Colors.redAccent.withAlpha(200),
                            fontSize: 10, height: 1.4),
                      )),
                    ]),
                  ),
                ],

                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: _outlineBtn('CANCELAR',
                          () => Navigator.pop(context))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _solidBtn('GUARDAR', _save)),
                  const SizedBox(width: 8),
                  Expanded(child: _dangerBtn('BORRAR', () {
                    widget.onDelete(widget.mp, widget.slots);
                    Navigator.pop(context);
                  })),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSpecialResultToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIPO DE RESULTADO',
            style: TextStyle(color: Colors.white.withAlpha(77),
                fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(children: [
          _typeChip('NORMAL',   SpecialResult.none,     Colors.white38),
          const SizedBox(width: 8),
          _typeChip('W.O.',     SpecialResult.walkover, Colors.orangeAccent),
          const SizedBox(width: 8),
          _typeChip('ABANDONO', SpecialResult.abandono, Colors.redAccent),
        ]),
      ],
    );
  }

  Widget _typeChip(String label, SpecialResult type, Color color) {
    final selected = _specialResult == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _specialResult = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : Colors.black.withAlpha(60),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : Colors.white.withAlpha(20),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: selected ? color : Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                )),
          ),
        ),
      ),
    );
  }

  Widget _header(String title, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(18)))),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: kYellow.withAlpha(26),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: kYellow, size: 14)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 12,
          fontWeight: FontWeight.bold, letterSpacing: 2)),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.close, color: Colors.white38, size: 14)),
      ),
    ]),
  );

  Widget _inputRow(String name, List<TextEditingController> ctrl) =>
      Row(children: [
        Expanded(child: Text(name.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
        ...ctrl.map((c) => Container(
          width: 44, height: 38, margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(color: Colors.black.withAlpha(102),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withAlpha(26))),
          child: TextField(controller: c, keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kYellow,
                  fontWeight: FontWeight.bold, fontSize: 18),
              decoration: const InputDecoration(border: InputBorder.none,
                  contentPadding: EdgeInsets.zero, counterText: ''),
              maxLength: 2),
        )),
      ]);

  Widget _vsDivider() => Row(children: [
    Expanded(child: Divider(color: Colors.white.withAlpha(15))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('VS', style: TextStyle(
            color: Colors.white.withAlpha(51), fontSize: 9, letterSpacing: 2))),
    Expanded(child: Divider(color: Colors.white.withAlpha(15))),
  ]);

  Widget _outlineBtn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withAlpha(31)))),
    child: Text(label, style: const TextStyle(color: Colors.white38,
        fontSize: 9, letterSpacing: 1.5)),
  );

  Widget _solidBtn(String label, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: kYellow,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0),
    child: Text(label, style: const TextStyle(color: Colors.black,
        fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2)),
  );

  Widget _dangerBtn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.red.withAlpha(100)))),
    child: Text(label, style: TextStyle(color: Colors.redAccent.withAlpha(200),
        fontSize: 9, letterSpacing: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE JUGADOR
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerModal extends StatefulWidget {
  final String        title;
  final String?       initialName;
  final String?       initialPhone;
  final bool          canBye;
  final VoidCallback? onBye;
  final Function(String, String) onSave;

  const _PlayerModal({
    required this.title,
    this.initialName, this.initialPhone,
    this.canBye  = false,
    this.onBye,
    required this.onSave,
  });

  @override
  State<_PlayerModal> createState() => _PlayerModalState();
}

class _PlayerModalState extends State<_PlayerModal> {
  late final TextEditingController _nameCtrl, _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initialName  ?? '');
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kYellow.withAlpha(51)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(179),
              blurRadius: 40, spreadRadius: 8)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              _field('NOMBRE COMPLETO', _nameCtrl),
              const SizedBox(height: 12),
              _field('CELULAR (WhatsApp)', _phoneCtrl,
                  type: TextInputType.phone),
              const SizedBox(height: 24),

              // Botón BYE (solo cuando hay oponente)
              if (widget.canBye && widget.onBye != null) ...[
                GestureDetector(
                  onTap: widget.onBye,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: const Center(
                      child: Text('ASIGNAR BYE',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.white.withAlpha(31)))),
                  child: const Text('CANCELAR',
                      style: TextStyle(color: Colors.white38,
                          fontSize: 10, letterSpacing: 1.5)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(
                        _nameCtrl.text.trim(), _phoneCtrl.text.trim());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kYellow,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0),
                  child: const Text('GUARDAR',
                      style: TextStyle(color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11, letterSpacing: 2)),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(18)))),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: kYellow.withAlpha(26),
              borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.person, color: kYellow, size: 14)),
      const SizedBox(width: 10),
      Text(widget.title, style: const TextStyle(color: Colors.white,
          fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.close, color: Colors.white38, size: 14)),
      ),
    ]),
  );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withAlpha(102),
            fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(height: 40,
          decoration: BoxDecoration(color: Colors.black.withAlpha(102),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withAlpha(26))),
          child: TextField(controller: ctrl, keyboardType: type,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10))),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO DE CONFIRMACIÓN
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String message;
  const _ConfirmDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withAlpha(80)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent.withAlpha(200), size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Colors.white38)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent),
              child: const Text('ELIMINAR',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE ASIGNACIÓN DE TURNO DE TORNEO — versión final
// • Duración variable
// • Disponibilidad en tiempo real (Stream)
// • Luz nocturna correcta (ocaso configurable)
// • Borra reservas anteriores con confirmación
// ─────────────────────────────────────────────────────────────────────────────
class _AssignTurnModal extends StatefulWidget {
  final String                         clubId;
  final String                         tournamentId;
  final MatchPosition                  mp;
  final Map<int, Map<String, dynamic>> slots;
  final Function(String date, String time, String courtId, String courtName,
      {String? endTime}) onAssigned;

  const _AssignTurnModal({
    required this.clubId,
    required this.tournamentId,
    required this.mp,
    required this.slots,
    required this.onAssigned,
  });

  @override
  State<_AssignTurnModal> createState() => _AssignTurnModalState();
}

class _AssignTurnModalState extends State<_AssignTurnModal> {
  DateTime _selectedDate     = DateTime.now();
  String?  _selectedTime;
  String?  _selectedCourtId;
  String?  _selectedCourtName;
  double   _durationHours    = 2.0;
  bool     _isSaving         = false;

  // Streams activos por cancha
  final Map<String, Stream<QuerySnapshot>> _courtStreams = {};
  // Datos de canchas (nombre, hasLights)
  List<QueryDocumentSnapshot> _courts = [];
  bool _courtsLoaded = false;

  // Turno anterior (si el partido ya tenía uno asignado)
  Map<String, dynamic>? get _previousSlot =>
      widget.slots[widget.mp.slotP1]?['matchSlot'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    final snap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').get();
    if (mounted) setState(() {
      _courts      = snap.docs;
      _courtsLoaded = true;
    });
  }

  // Slots de hora inicio disponibles según duración — de 30 en 30
  List<String> get _timeSlots {
    final maxMin = (22 - _durationHours) * 60;
    final result  = <String>[];
    for (int min = 7 * 60; min <= maxMin; min += 30) {
      final h = min ~/ 60;
      final m = min % 60;
      result.add('${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}');
    }
    return result;
  }

  // Todos los slots de 30 min que ocupa el bloque
  List<String> _slotsForBlock(String startTime) {
    final parts    = startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final totalMin = (_durationHours * 60).round();
    final result   = <String>[];
    // Pasos de 30 min — igual que la agenda de canchas
    for (int m = startMin; m < startMin + totalMin; m += 30) {
      result.add('${(m ~/ 60).toString().padLeft(2,'0')}:${(m % 60).toString().padLeft(2,'0')}');
    }
    return result;
  }

  String _endTime(String startTime) {
    final parts    = startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final endMin   = startMin + (_durationHours * 60).round();
    return '${(endMin ~/ 60).toString().padLeft(2,'0')}:${(endMin % 60).toString().padLeft(2,'0')}';
  }

  // Verificar si un slot cae en horario nocturno (>= 20:00 aprox)
  bool _isNightSlot(String time) {
    final h = int.tryParse(time.split(':')[0]) ?? 0;
    return h >= 20;
  }

  // Obtener stream de reservas de una cancha para la fecha seleccionada
  Stream<QuerySnapshot> _streamForCourt(String courtId) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _courtStreams[courtId] ??= FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').doc(courtId)
        .collection('reservations')
        .where('date', isEqualTo: dateStr)
        .snapshots();
    return _courtStreams[courtId]!;
  }

  // Evaluar disponibilidad de una cancha dado un set de tiempos ocupados
  String? _blockReason(QueryDocumentSnapshot courtDoc, Set<String> occupied) {
    if (_selectedTime == null) return null;
    final data      = courtDoc.data() as Map<String, dynamic>;
    final hasLights = data['hasLights'] == true;
    final needed    = _slotsForBlock(_selectedTime!);

    // Chequear luz nocturna
    if (!hasLights && needed.any(_isNightSlot)) {
      return 'Sin luz nocturna';
    }

    // Chequear ocupación
    final conflict = needed.where((s) => occupied.contains(s)).toList();
    if (conflict.isNotEmpty) return 'Ocupada a las ${conflict.first}';

    return null; // disponible
  }

  void _resetOnDateOrDurationChange() {
    setState(() {
      _selectedTime      = null;
      _selectedCourtId   = null;
      _selectedCourtName = null;
      _courtStreams.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n1 = (widget.slots[widget.mp.slotP1]?['name'] ?? '').toString();
    final n2 = (widget.slots[widget.mp.slotP2]?['name'] ?? '').toString();
    final prev = _previousSlot;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kYellow.withAlpha(51)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(179),
              blurRadius: 40, spreadRadius: 8)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── JUGADORES ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(child: _playerChip(n1)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('VS', style: TextStyle(
                              color: Colors.white38, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                        ),
                        Flexible(child: _playerChip(n2)),
                      ],
                    ),
                  ),

                  // ── BANNER TURNO ANTERIOR ─────────────────────────────────
                  if (prev != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orangeAccent.withAlpha(60)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Turno anterior: ${prev['courtName']} · '
                            '${prev['date']} · ${prev['time']}',
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 10),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── FECHA ─────────────────────────────────────────────────
                  _sectionLabel('FECHA'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: kYellow, surface: Color(0xFF1A3A34)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _resetOnDateOrDurationChange();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withAlpha(26)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            color: kYellow, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat("EEEE dd 'de' MMMM", 'es')
                              .format(_selectedDate).toUpperCase(),
                          style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── DURACIÓN ──────────────────────────────────────────────
                  _sectionLabel('DURACIÓN ESTIMADA'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [1.0, 1.5, 2.0, 2.5, 3.0].map((h) {
                      final sel   = _durationHours == h;
                      final isInt = h == h.truncateToDouble();
                      final label = isInt ? '${h.toInt()}h' : '${h.toInt()}h 30m';
                      return GestureDetector(
                        onTap: () {
                          setState(() => _durationHours = h);
                          _resetOnDateOrDurationChange();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? kYellow.withAlpha(30)
                                : Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? kYellow : Colors.white.withAlpha(26),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(label, style: TextStyle(
                            color: sel ? kYellow : Colors.white70,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── HORA DE INICIO ────────────────────────────────────────
                  _sectionLabel('HORA DE INICIO'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _timeSlots.map((time) {
                      final sel = _selectedTime == time;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedTime      = time;
                          _selectedCourtId   = null;
                          _selectedCourtName = null;
                          _courtStreams.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? kYellow.withAlpha(30)
                                : Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? kYellow : Colors.white.withAlpha(20),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(time, style: TextStyle(
                            color: sel ? kYellow : Colors.white70,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── CANCHAS EN TIEMPO REAL ────────────────────────────────
                  if (_selectedTime != null && _courtsLoaded) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('CANCHA DISPONIBLE'),
                    const SizedBox(height: 8),
                    Column(
                      children: _courts.map((courtDoc) {
                        final data      = courtDoc.data() as Map<String, dynamic>;
                        final name      = data['courtName']?.toString() ?? courtDoc.id;
                        final hasLights = data['hasLights'] == true;
                        final isSelected = _selectedCourtId == courtDoc.id;

                        return StreamBuilder<QuerySnapshot>(
                          stream: _streamForCourt(courtDoc.id),
                          builder: (ctx, snap) {
                            final occupied = snap.hasData
                                ? snap.data!.docs
                                    .map((d) => (d.data() as Map<String,dynamic>)['time']?.toString() ?? '')
                                    .toSet()
                                : <String>{};

                            final String? blockReasonRaw = _blockReason(courtDoc, occupied);
                            final blockReason  = blockReasonRaw ?? '';
                            final isAvailable  = blockReasonRaw == null;

                            return GestureDetector(
                              onTap: isAvailable
                                  ? () => setState(() {
                                        _selectedCourtId   = courtDoc.id;
                                        _selectedCourtName = name;
                                      })
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kYellow.withAlpha(20)
                                      : isAvailable
                                          ? Colors.greenAccent.withAlpha(10)
                                          : Colors.white.withAlpha(4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? kYellow
                                        : isAvailable
                                            ? Colors.greenAccent.withAlpha(80)
                                            : Colors.white.withAlpha(12),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(children: [
                                  Icon(
                                    hasLights
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    color: isSelected
                                        ? kYellow
                                        : isAvailable
                                            ? Colors.greenAccent
                                            : Colors.white24,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(name, style: TextStyle(
                                      color: isSelected
                                          ? kYellow
                                          : isAvailable
                                              ? Colors.white
                                              : Colors.white24,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    )),
                                  ),
                                  // Badge de estado
                                  if (!snap.hasData)
                                    const SizedBox(
                                      width: 12, height: 12,
                                      child: CircularProgressIndicator(
                                          color: kYellow, strokeWidth: 1.5),
                                    )
                                  else if (isSelected)
                                    const Icon(Icons.check_circle,
                                        color: kYellow, size: 16)
                                  else if (isAvailable)
                                    _badge('LIBRE', Colors.greenAccent)
                                  else
                                    _badge(blockReason, Colors.redAccent),
                                ]),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // ── RESUMEN ───────────────────────────────────────────────
                  if (_selectedTime != null && _selectedCourtId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kYellow.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kYellow.withAlpha(40)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: kYellow, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_selectedCourtName · '
                            '${_selectedTime!} – ${_endTime(_selectedTime!)} · '
                            '${_slotsForBlock(_selectedTime!).length} slot(s)',
                            style: const TextStyle(
                                color: kYellow, fontSize: 10),
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── BOTÓN CONFIRMAR ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedCourtId != null &&
                              _selectedTime != null && !_isSaving)
                          ? _tryConfirm
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kYellow,
                        disabledBackgroundColor: Colors.white.withAlpha(13),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Text(
                              _selectedCourtId == null || _selectedTime == null
                                  ? 'ELEGÍ HORA Y CANCHA'
                                  : 'CONFIRMAR TURNO',
                              style: TextStyle(
                                color: _selectedCourtId != null &&
                                        _selectedTime != null
                                    ? Colors.black
                                    : Colors.white24,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // Intenta confirmar — si hay turno anterior, pide confirmación primero
  Future<void> _tryConfirm() async {
    final prev = _previousSlot;

    if (prev != null) {
      final prevCourt = prev['courtName'] ?? '';
      final prevDate  = prev['date']      ?? '';
      final prevTime  = prev['time']      ?? '';

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D1220),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.orangeAccent.withAlpha(80))),
          title: const Text('Cambiar turno asignado',
              style: TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.bold)),
          content: Text(
            'Se cancelará el turno anterior:\n'
            '$prevCourt · $prevDate · $prevTime\n\n'
            'Y se creará uno nuevo:\n'
            '$_selectedCourtName · '
            '${DateFormat('yyyy-MM-dd').format(_selectedDate)} · '
            '$_selectedTime – ${_endTime(_selectedTime!)}',
            style: const TextStyle(color: Colors.white70,
                fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('CONFIRMAR',
                  style: TextStyle(color: Colors.black,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (ok != true) return;

      // Borrar reservas anteriores
      await _deletePreviousReservations(prev);
    }

    await _confirm();
  }

  // Borrar todas las reservas del turno anterior en Firestore
  Future<void> _deletePreviousReservations(Map<String, dynamic> prev) async {
    final prevCourtId = prev['courtId']?.toString() ?? '';
    final prevDate    = prev['date']?.toString()    ?? '';
    final prevTime    = prev['time']?.toString()    ?? '';
    if (prevCourtId.isEmpty || prevDate.isEmpty) return;

    // Buscar todas las reservas de ese partido en esa cancha/fecha
    final snap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').doc(prevCourtId)
        .collection('reservations')
        .where('date', isEqualTo: prevDate)
        .where('tournamentId', isEqualTo: widget.tournamentId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      // Solo borrar los del bloque anterior (blockStart coincide o time == prevTime)
      final docData  = doc.data();
      final docBlock = docData['blockStart']?.toString() ?? docData['time']?.toString() ?? '';
      if (docBlock == prevTime) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  Future<void> _confirm() async {
    if (_selectedCourtId == null || _selectedTime == null) return;
    setState(() => _isSaving = true);

    final dateStr     = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final neededSlots = _slotsForBlock(_selectedTime!);
    final endT        = _endTime(_selectedTime!);
    final n1 = (widget.slots[widget.mp.slotP1]?['name'] ?? '').toString();
    final n2 = (widget.slots[widget.mp.slotP2]?['name'] ?? '').toString();

    // Re-validar disponibilidad antes de guardar
    final resSnap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('courts').doc(_selectedCourtId)
        .collection('reservations')
        .where('date', isEqualTo: dateStr)
        .get();

    final occupied = resSnap.docs
        .map((d) => d.data()['time']?.toString() ?? '')
        .toSet();

    final conflict = neededSlots.where((s) => occupied.contains(s)).toList();
    if (conflict.isNotEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Conflicto: ${conflict.first} ya está ocupado en $_selectedCourtName'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    // Crear reservas en batch (una por slot)
    final batch = FirebaseFirestore.instance.batch();
    for (final slotTime in neededSlots) {
      final ref = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('courts').doc(_selectedCourtId)
          .collection('reservations').doc();
      batch.set(ref, {
        'date':         dateStr,
        'time':         slotTime,
        'type':         'torneo',
        'modality':     'singles',
        'playerName':   '$n1 vs $n2',
        'phone':        '',
        'tournamentId': widget.tournamentId,
        'blockStart':   _selectedTime,
        'blockEnd':     endT,
        'amount':       0,
        'status':       'confirmed',
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (mounted) {
      Navigator.pop(context);
      widget.onAssigned(
        dateStr, _selectedTime!, _selectedCourtId!, _selectedCourtName!,
        endTime: endT,
      );
    }
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
            color: Colors.white.withAlpha(18)))),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: kYellow.withAlpha(26),
            borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.schedule, color: kYellow, size: 14),
      ),
      const SizedBox(width: 10),
      const Text('ASIGNAR TURNO',
          style: TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.close, color: Colors.white38, size: 14),
        ),
      ),
    ]),
  );

  Widget _sectionLabel(String label) => Text(label,
      style: TextStyle(color: Colors.white.withAlpha(77),
          fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5));

  Widget _playerChip(String name) => Text(name.toUpperCase(),
      style: const TextStyle(color: Colors.white,
          fontSize: 11, fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis);
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _BgGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withAlpha(3)
      ..strokeWidth = 0.5
      ..style       = PaintingStyle.stroke;
    const step = 60.0;
    for (double x = 0; x < size.width;  x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_BgGridPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE SORTEO — aleatorio o manual
// ─────────────────────────────────────────────────────────────────────────────
class _DrawModal extends StatefulWidget {
  final List<Map<String, dynamic>> players;
  final int slotCount;
  final Future<void> Function(List<Map<String, dynamic>>) onConfirm;

  const _DrawModal({
    required this.players,
    required this.slotCount,
    required this.onConfirm,
  });

  @override
  State<_DrawModal> createState() => _DrawModalState();
}

class _DrawModalState extends State<_DrawModal> {
  bool _isRandom = true;
  bool _saving   = false;

  // Para sorteo manual: lista de slots, cada uno con el jugador asignado (o null)
  late List<Map<String, dynamic>?> _manualSlots;
  // Jugadores aún sin asignar
  late List<Map<String, dynamic>> _unassigned;

  @override
  void initState() {
    super.initState();
    _manualSlots = List.filled(widget.slotCount, null);
    _unassigned  = List.from(widget.players);
  }

  List<Map<String, dynamic>> _randomOrder() {
    final shuffled = List<Map<String, dynamic>>.from(widget.players)
      ..shuffle(Random());
    return shuffled;
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final List<Map<String, dynamic>> ordered;
      if (_isRandom) {
        ordered = _randomOrder();
      } else {
        // Solo los slots asignados; los vacíos no generan entrada
        ordered = _manualSlots
            .where((s) => s != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
      await widget.onConfirm(ordered);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _assignToSlot(int slotIdx, Map<String, dynamic> player) {
    setState(() {
      // Si ya estaba en otro slot, liberar ese slot
      for (int i = 0; i < _manualSlots.length; i++) {
        if (_manualSlots[i]?['uid'] == player['uid']) {
          _manualSlots[i] = null;
        }
      }
      // Si el slot ya tenía alguien, devolverlo a no asignados
      final prev = _manualSlots[slotIdx];
      if (prev != null) {
        _unassigned.add(prev);
      }
      _manualSlots[slotIdx] = player;
      _unassigned.removeWhere((p) => p['uid'] == player['uid']);
    });
  }

  void _clearSlot(int slotIdx) {
    final prev = _manualSlots[slotIdx];
    if (prev == null) return;
    setState(() {
      _manualSlots[slotIdx] = null;
      _unassigned.add(prev);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              const Text('GENERAR SORTEO',
                  style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              // Toggle modo
              GestureDetector(
                onTap: () => setState(() => _isRandom = !_isRandom),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kYellow.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _isRandom ? Icons.shuffle : Icons.edit_outlined,
                      color: kYellow, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _isRandom ? 'ALEATORIO' : 'MANUAL',
                      style: const TextStyle(
                          color: kYellow,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _isRandom
                  ? '${widget.players.length} jugadores inscriptos · se sortearán al azar'
                  : 'Asigná cada jugador a una posición del bracket',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isRandom
                ? _buildRandomPreview(scrollCtrl)
                : _buildManualAssign(scrollCtrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _confirm,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black))
                    : Text(
                        _isRandom
                            ? 'SORTEAR Y COMENZAR TORNEO'
                            : 'CONFIRMAR Y COMENZAR TORNEO',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRandomPreview(ScrollController ctrl) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: widget.players.length,
      itemBuilder: (_, i) {
        final p     = widget.players[i];
        final photo = p['photoUrl']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: kYellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: kYellow, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1A3A34),
              backgroundImage: photo.isNotEmpty
                  ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person,
                      size: 16, color: Colors.white38)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(p['name']?.toString() ?? 'Jugador',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
            const Spacer(),
            const Icon(Icons.shuffle, color: Colors.white24, size: 14),
          ]),
        );
      },
    );
  }

  Widget _buildManualAssign(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        // Jugadores sin asignar
        if (_unassigned.isNotEmpty) ...[
          const Text('JUGADORES SIN ASIGNAR',
              style: TextStyle(color: Colors.white38,
                  fontSize: 9, fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _unassigned.map((p) {
              final photo = p['photoUrl']?.toString() ?? '';
              return GestureDetector(
                onTap: () {
                  // Asignar al primer slot libre
                  final freeIdx = _manualSlots.indexWhere(
                      (s) => s == null);
                  if (freeIdx != -1) _assignToSlot(freeIdx, p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kYellow.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: kYellow.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF1A3A34),
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? const Icon(Icons.person,
                              size: 10, color: Colors.white38)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(p['name']?.toString() ?? 'Jugador',
                        style: const TextStyle(
                            color: kYellow, fontSize: 11)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Slots del bracket
        const Text('POSICIONES EN EL BRACKET',
            style: TextStyle(color: Colors.white38,
                fontSize: 9, fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...List.generate(widget.slotCount, (i) {
          final assigned = _manualSlots[i];
          final photo    = assigned?['photoUrl']?.toString() ?? '';
          return GestureDetector(
            onTap: assigned != null
                ? () => _clearSlot(i)
                : () {
                    // Si hay no asignados, mostrar selector
                    if (_unassigned.isNotEmpty) {
                      _showPlayerSelector(i);
                    }
                  },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: assigned != null
                    ? Colors.greenAccent.withOpacity(0.05)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: assigned != null
                      ? Colors.greenAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                if (assigned != null) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF1A3A34),
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? const Icon(Icons.person,
                            size: 14, color: Colors.white38)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        assigned['name']?.toString() ?? 'Jugador',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  const Icon(Icons.close,
                      color: Colors.white38, size: 14),
                ] else ...[
                  const Expanded(
                    child: Text('Tocar para asignar jugador',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 12)),
                  ),
                  const Icon(Icons.add_circle_outline,
                      color: Colors.white24, size: 16),
                ],
              ]),
            ),
          );
        }),
      ],
    );
  }

  void _showPlayerSelector(int slotIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131824),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('SELECCIONÁ UN JUGADOR',
              style: TextStyle(color: Colors.white38,
                  fontSize: 10, fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ..._unassigned.map((p) {
            final photo = p['photoUrl']?.toString() ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1A3A34),
                backgroundImage: photo.isNotEmpty
                    ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Icons.person,
                        size: 18, color: Colors.white38)
                    : null,
              ),
              title: Text(p['name']?.toString() ?? 'Jugador',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _assignToSlot(slotIdx, p);
              },
            );
          }),
        ],
      ),
    );
  }
}