// =============================================================================
// PATCH COMPLETO — tournament_management_screen.dart
// Aplicar los 6 cambios marcados con ← PATCH
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// PATCH 1 — IMPORTS (agregar junto a los existentes, al tope del archivo)
// ─────────────────────────────────────────────────────────────────────────────
import 'stats_calculator.dart';        // ← PATCH
import 'tournament_stats_screen.dart'; // ← PATCH


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 2 — CAMPOS DEL STATE
// Dentro de _TournamentManagementScreenState, agregar junto a _userRole y _isLoading:
// ─────────────────────────────────────────────────────────────────────────────

  RankingConfig _rankingConfig = const RankingConfig(); // ← PATCH


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 3 — initState
// Agregar _loadRankingConfig() al initState existente:
// ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _layout = BracketLayout(_nearestValidCount(widget.playerCount));
    _loadUserRole();
    _loadRankingConfig(); // ← PATCH
  }


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 4 — NUEVO MÉTODO _loadRankingConfig
// Agregar junto a _loadUserRole():
// ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadRankingConfig() async { // ← PATCH (método completo nuevo)
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
      });
    }
  }


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 5 — REEMPLAZAR _saveResult completo
// Buscar el método _saveResult existente y reemplazarlo con este:
// ─────────────────────────────────────────────────────────────────────────────

  void _saveResult( // ← PATCH (método reemplazado)
    int p1, int p2, int nextSlot,
    List<String> score, int winnerSlot,
    Map<int, Map<String, dynamic>> slots,
  ) {
    final updated = Map<int, Map<String, dynamic>>.from(slots);
    updated[p1] = {
      ...(slots[p1] ?? {}), 'score': score, 'winner': p1 == winnerSlot,
    };
    updated[p2] = {
      ...(slots[p2] ?? {}), 'score': score, 'winner': p2 == winnerSlot,
    };
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
    // Persistir y luego recalcular stats en background
    _persist(updated).then((_) => _triggerStatsRecalc(updated));
  }


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 5b — NUEVO MÉTODO _triggerStatsRecalc
// Agregar justo después de _saveResult:
// ─────────────────────────────────────────────────────────────────────────────

  Future<void> _triggerStatsRecalc( // ← PATCH (método completo nuevo)
    Map<int, Map<String, dynamic>> slots,
  ) async {
    final layoutInfo = BracketLayoutInfo(
      totalRounds: _layout.totalRounds,
      matches: _layout.matches
          .map((mp) => MatchInfo(
                slotP1:   mp.slotP1,
                slotP2:   mp.slotP2,
                nextSlot: mp.nextSlot,
                round:    mp.round,
                isFinal:  mp.isFinal,
              ))
          .toList(),
    );

    await StatsCalculator.recalculate(
      tournamentId:  widget.tournamentId,
      slots:         slots,
      layoutInfo:    layoutInfo,
      rankingConfig: _rankingConfig,
    );
  }


// ─────────────────────────────────────────────────────────────────────────────
// PATCH 6 — APPBAR: agregar botón de stats en actions[]
// Dentro de _buildAppBar(), en actions: [], agregar ANTES del Container del badge:
// ─────────────────────────────────────────────────────────────────────────────

    // ← PATCH: botón stats
    IconButton(
      icon: const Icon(
          Icons.bar_chart_rounded, color: Colors.white70, size: 20),
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

// =============================================================================
// FIN DEL PATCH
// =============================================================================
