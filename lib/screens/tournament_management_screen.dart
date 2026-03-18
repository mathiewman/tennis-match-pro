import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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

  String _userRole  = 'player';
  bool   _isLoading = true;
  late final BracketLayout _layout;
  RankingConfig _rankingConfig = const RankingConfig();
  String? _lastRecalculatedTournamentId;
  bool _isRankingConfigLoaded = false;

  // Control de zoom y posición inicial
  final TransformationController _transformCtrl = TransformationController();
  bool _initialPositionSet = false;

  @override
  void initState() {
    super.initState();
    _layout = BracketLayout(_nearestValidCount(widget.playerCount));
    _loadUserRole();
    _loadRankingConfig();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  /// Detecta la ronda activa (última con al menos un partido jugado)
  /// y centra la vista ahí con zoom legible.
  /// Si no hay ningún partido jugado, centra en la ronda 0 (primera ronda).
  void _setInitialPosition(Map<int, Map<String, dynamic>> slots, Size screenSize) {
    if (_initialPositionSet) return;
    _initialPositionSet = true;

    // Encontrar la ronda más avanzada con al menos un resultado cargado
    int activeRound = 0;
    for (final mp in _layout.matches) {
      final s1 = slots[mp.slotP1];
      final s2 = slots[mp.slotP2];
      final hasResult = (s1?['score'] as List?)?.isNotEmpty == true ||
          (s2?['score'] as List?)?.isNotEmpty == true;
      if (hasResult && mp.round >= activeRound) {
        activeRound = mp.round;
      }
    }

    // Buscar todos los matches de esa ronda
    final matchesInRound = _layout.matches
        .where((mp) => mp.round == activeRound)
        .toList();

    if (matchesInRound.isEmpty) return;

    // Posición X: la columna de esa ronda
    final double targetX = matchesInRound.first.x;

    // Posición Y: centro vertical de todos los matches de esa ronda
    final double minY = matchesInRound.map((m) => m.y).reduce((a, b) => a < b ? a : b);
    final double maxY = matchesInRound.map((m) => m.y).reduce((a, b) => a > b ? a : b) + kMatchH;
    final double targetY = (minY + maxY) / 2;

    // Zoom según cantidad de matches en la ronda
    final double scale = matchesInRound.length <= 4 ? 1.0 : 0.75;

    // Centrar la vista: mover el canvas para que targetX,targetY quede en el centro de pantalla
    final double offsetX = -(targetX * scale) + (screenSize.width  / 2) - (kMatchW * scale / 2) - 60;
    final double offsetY = -(targetY * scale) + (screenSize.height / 2) - 60;

    _transformCtrl.value = Matrix4.identity()
      ..scale(scale)
      ..translate(offsetX / scale, offsetY / scale);
  }

  int _nearestValidCount(int n) {
    for (final v in [4, 8, 16, 32]) { if (v >= n) return v; }
    return 32;
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (mounted) setState(() {
        _userRole  = doc.data()?['role'] ?? 'player';
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
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
      Map<int, Map<String, dynamic>> slots,
      ) {
    final updated = Map<int, Map<String, dynamic>>.from(slots);
    updated[p1] = {...(slots[p1] ?? {}), 'score': score, 'winner': p1 == winnerSlot};
    updated[p2] = {...(slots[p2] ?? {}), 'score': score, 'winner': p2 == winnerSlot};
    if (nextSlot != -1) {
      final w = updated[winnerSlot]!;
      updated[nextSlot] = {
        'name':     w['name']     ?? '',
        'phone':    w['phone']    ?? '',
        'photoUrl': w['photoUrl'] ?? '',
        'score':    [],
        'winner':   false,
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
  void _deleteResult(MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    final updated = Map<int, Map<String, dynamic>>.from(slots);
    updated[mp.slotP1] = {...(slots[mp.slotP1] ?? {}), 'score': [], 'winner': false};
    updated[mp.slotP2] = {...(slots[mp.slotP2] ?? {}), 'score': [], 'winner': false};

    if (mp.nextSlot != -1) {
      final p1n = slots[mp.slotP1]?['name'] ?? '';
      final p2n = slots[mp.slotP2]?['name'] ?? '';
      final nn  = slots[mp.nextSlot]?['name'] ?? '';
      if (nn.isNotEmpty && (nn == p1n || nn == p2n)) {
        _cascadeClearByName(updated, nn, startSlot: mp.nextSlot);
      }
    }
    _persist(updated).then((_) => _triggerStatsRecalc(updated)); // ADDED: Trigger recalc after deleting result
  }

  // ── AGREGAR JUGADOR ───────────────────────────────────────────────────────
  void _addPlayer(int slotIndex, Map<int, Map<String, dynamic>> slots) {
    showDialog(
      context: context,
      builder: (_) => _PlayerModal(
        title: 'AGREGAR JUGADOR',
        onSave: (name, phone) {
          final updated = Map<int, Map<String, dynamic>>.from(slots);
          updated[slotIndex] = {
            'name': name, 'phone': phone,
            'photoUrl': '', 'score': [], 'winner': false,
          };
          _persist(updated).then((_) => _triggerStatsRecalc(updated)); // ADDED: Trigger recalc after adding player
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

  // ── EDITAR SCORE ──────────────────────────────────────────────────────────
  void _editScore(MatchPosition mp, Map<int, Map<String, dynamic>> slots) {
    showDialog(
      context: context,
      builder: (_) => _ScoreModal(
        mp: mp, slots: slots,
        onSave:   _saveResult,
        onDelete: _deleteResult,
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _layoutDoc.snapshots(),
        builder: (context, snapshot) {
          final slots    = _parseSlots(snapshot);
          final screenW  = MediaQuery.of(context).size.width;
          final minScale = ((screenW - 40) / _layout.totalWidth).clamp(0.01, 1.0);

          // Setear posición inicial una sola vez cuando llegan los datos
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setInitialPosition(slots, MediaQuery.of(context).size);
            });
          }

          if (snapshot.hasData && snapshot.data!.exists && _isRankingConfigLoaded && _lastRecalculatedTournamentId != widget.tournamentId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerStatsRecalc(slots);
            });
          }

          return InteractiveViewer(
            transformationController: _transformCtrl,
            minScale:        minScale,
            maxScale:        3.0,
            boundaryMargin:  const EdgeInsets.all(4000),
            constrained:     false,
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: _BracketCanvas(
                layout:         _layout,
                slots:          slots,
                isAdmin:        _isAdmin,
                onSave:         _saveResult,
                onAddPlayer:    _isAdmin ? (i)       => _addPlayer(i, slots)         : null,
                onEditPlayer:   _isAdmin ? (i, data) => _editPlayer(i, data, slots)  : null,
                onDeletePlayer: _isAdmin ? (i)       => _deletePlayer(i, slots)      : null,
                onEditScore:    _isAdmin ? (mp)      => _editScore(mp, slots)        : null,
              ),
            ),
          );
        },
      ),
    );
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
      // ← NUEVO: botón de estadísticas
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
// BRACKET CANVAS
// ─────────────────────────────────────────────────────────────────────────────
class _BracketCanvas extends StatelessWidget {
  final BracketLayout                  layout;
  final Map<int, Map<String, dynamic>> slots;
  final bool                           isAdmin;
  final Function(int, int, int, List<String>, int, Map<int, Map<String, dynamic>>) onSave;
  final Function(int)?                       onAddPlayer;
  final Function(int, Map<String, dynamic>)? onEditPlayer;
  final Function(int)?                       onDeletePlayer;
  final Function(MatchPosition)?             onEditScore;

  const _BracketCanvas({
    required this.layout,
    required this.slots,
    required this.isAdmin,
    required this.onSave,
    this.onAddPlayer,
    this.onEditPlayer,
    this.onDeletePlayer,
    this.onEditScore,
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
                return Positioned(
                  left: mp.x, top: mp.y - 22, width: kMatchW,
                  child: Center(child: Text(_roundLabel(mp.round),
                      style: const TextStyle(color: Color(0xFF2E4270),
                          fontSize: 8, fontWeight: FontWeight.bold,
                          letterSpacing: 2.5))),
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

  const _MatchBox({
    required this.mp,
    required this.slots,
    required this.isAdmin,
    this.onAddPlayer,
    this.onEditPlayer,
    this.onDeletePlayer,
    this.onEditScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            ? [BoxShadow(color: kYellow.withAlpha(15), blurRadius: 24, spreadRadius: 4)]
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

  bool   get _hasPlayer => data != null && (data!['name'] ?? '').toString().isNotEmpty;
  String get _name      => _hasPlayer ? (data!['name'] as String).toUpperCase() : '';
  bool   get _isWinner  => data?['winner'] == true;

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
    if (!isAdmin) {
      return Text(
        _hasPlayer ? _name : 'ESPERANDO...',
        style: TextStyle(
          color: _hasPlayer ? (_isWinner ? Colors.white : Colors.white60) : Colors.white.withAlpha(51),
          fontSize: 10, letterSpacing: 0.3,
          fontWeight: _isWinner ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (_hasPlayer) {
      return GestureDetector(
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
      );
    }
    if (mp.round == 0) {
      return GestureDetector(
        onTap: () => onAddPlayer?.call(slotIndex),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_circle_outline, color: Colors.white38, size: 13),
          const SizedBox(width: 3),
          const Text('AGREGAR',
              style: TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      );
    }
    return Text('ESPERANDO...',
        style: TextStyle(color: Colors.white.withAlpha(51), fontSize: 10));
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
class _ScoreModal extends StatefulWidget {
  final MatchPosition                  mp;
  final Map<int, Map<String, dynamic>> slots;
  final Function(int, int, int, List<String>, int, Map<int, Map<String, dynamic>>) onSave;
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

  int _winner() {
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
    widget.onSave(widget.mp.slotP1, widget.mp.slotP2,
        widget.mp.nextSlot, scores, _winner(), widget.slots);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
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
  final String  title;
  final String? initialName;
  final String? initialPhone;
  final Function(String, String) onSave;

  const _PlayerModal({
    required this.title,
    this.initialName, this.initialPhone,
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