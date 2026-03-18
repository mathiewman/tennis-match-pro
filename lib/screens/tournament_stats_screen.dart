import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stats_calculator.dart';
import 'ranking_config_modal.dart';
import 'player_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORES DEL TEMA — definidos como privados para evitar conflicto con
// player_detail_sheet.dart que define los mismos nombres a nivel de archivo.
// Usamos el prefijo _k para que sean privados a este archivo.
// ─────────────────────────────────────────────────────────────────────────────
const Color _kBg            = Color(0xFF0A0F1E);
const Color _kCardBg        = Color(0xFF12172B);
const Color _kAccentGreen   = Color(0xFF00FF41);
const Color _kAccentBlue    = Color(0xFF0085C7);
const Color _kTextPrimary   = Colors.white;
const Color _kTextSecondary = Colors.white70;

// ─────────────────────────────────────────────────────────────────────────────
class TournamentStatsScreen extends StatefulWidget {
  final String        clubId;
  final String        tournamentId;
  final String        tournamentName;
  final bool          isAdmin;
  final RankingConfig rankingConfig;
  final void Function(RankingConfig) onConfigSaved;

  const TournamentStatsScreen({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentName,
    required this.isAdmin,
    required this.rankingConfig,
    required this.onConfigSaved,
  });

  @override
  State<TournamentStatsScreen> createState() => _TournamentStatsScreenState();
}

class _TournamentStatsScreenState extends State<TournamentStatsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  int  _selectedYear = DateTime.now().year;
  int  _sortColT     = 14;
  bool _sortAscT     = false;
  int  _sortColA     = 14;
  bool _sortAscA     = false;

  // Config local mutable — se actualiza cuando el admin guarda cambios
  late RankingConfig _localRankingConfig;

  @override
  void initState() {
    super.initState();
    _localRankingConfig = widget.rankingConfig;
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── LABELS ────────────────────────────────────────────────────────────────
  static const List<String> _cols = [
    '#', '', 'JUGADOR', 'RESULT',
    'PJ', 'PG', 'PP', '%G',
    'SG', 'SP', '%S',
    'GG', 'GP', '%J',
    'PTS', 'RACHA',
  ];
  static const List<String> _colsAnnual = [
    '#', '', 'JUGADOR',
    'PJ', 'PG', 'PP', '%G',
    'SG', 'SP', '%S',
    'GG', 'GP', '%J',
    'PTS', 'RACHA', 'TORNEOS',
  ];

  static const Map<String, String> _colTooltips = {
    'PJ':     'Partidos Jugados',
    'PG':     'Partidos Ganados',
    'PP':     'Partidos Perdidos',
    '%G':     'Porcentaje de victorias en partidos',
    'SG':     'Sets Ganados',
    'SP':     'Sets Perdidos',
    '%S':     'Porcentaje de sets ganados',
    'GG':     'Games Ganados',
    'GP':     'Games Perdidos',
    '%J':     'Porcentaje de games individuales ganados',
    'PTS':    'Puntos de Ranking',
    'RACHA':  'Partidos consecutivos ganados (+) o perdidos (-)',
    'RESULT': 'Resultado en el torneo',
    'TORNEOS':'Cantidad de torneos jugados en el año',
  };

  static const List<double> _widths = [
    30, 40, 150, 90,
    40, 40, 40, 50,
    40, 40, 50,
    40, 40, 50,
    50, 60,
  ];
  static const List<double> _widthsAnnual = [
    30, 40, 150,
    40, 40, 40, 50,
    40, 40, 50,
    40, 40, 50,
    50, 60, 70,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
            [_buildAppBar(innerBoxIsScrolled)],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildTournamentTab(),
            _buildAnnualTab(),
          ],
        ),
      ),
      floatingActionButton: widget.isAdmin ? _buildFAB() : null,
    );
  }

  SliverAppBar _buildAppBar(bool innerBoxIsScrolled) => SliverAppBar(
    backgroundColor: Colors.black,
    elevation: 0,
    pinned: true,
    floating: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, color: _kTextPrimary, size: 18),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.tournamentName.toUpperCase(),
          style: GoogleFonts.exo2(
              color: _kTextPrimary, fontSize: 13,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
      Text('ESTADÍSTICAS',
          style: GoogleFonts.exo2(
              color: _kAccentGreen, fontSize: 9, letterSpacing: 2)),
    ]),
    actions: const [
      Padding(
        padding: EdgeInsets.only(right: 16),
        child: Icon(Icons.sports_tennis_rounded, color: _kAccentGreen, size: 24),
      ),
    ],
    bottom: TabBar(
      controller: _tabCtrl,
      indicatorColor: _kAccentGreen,
      indicatorWeight: 2,
      labelColor: _kAccentGreen,
      unselectedLabelColor: Colors.white38,
      labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      tabs: const [
        Tab(text: 'ESTE TORNEO'),
        Tab(text: 'RANKING ANUAL'),
      ],
    ),
  );

  // ── TAB 1: ESTE TORNEO ────────────────────────────────────────────────────
  Widget _buildTournamentTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments').doc(widget.tournamentId)
          .collection('stats').doc('summary')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccentGreen));
        }
        if (snap.hasError) return _emptyState('Error: ${snap.error}');
        if (!snap.hasData || !snap.data!.exists) {
          return _emptyState('Aún no hay resultados cargados.');
        }

        final raw = (snap.data!.data() as Map<String, dynamic>)['players'];
        if (raw is! List || raw.isEmpty) {
          return _emptyState('Aún no hay resultados cargados.');
        }

        var players = raw
            .map((p) => PlayerStats.fromMap(Map<String, dynamic>.from(p)))
            .toList();

        final nameCounts = <String, int>{};
        for (var p in players) nameCounts[p.name] = (nameCounts[p.name] ?? 0) + 1;
        final duplicated = nameCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

        players = _sortPlayers(players, _sortColT, _sortAscT);

        return _buildTable(
          players: players,
          cols: _cols,
          widths: _widths,
          sortCol: _sortColT,
          sortAsc: _sortAscT,
          showResult: true,
          showTournaments: false,
          onSort: (i) => setState(() {
            if (_sortColT == i) { _sortAscT = !_sortAscT; }
            else { _sortColT = i; _sortAscT = false; }
          }),
          onTapRow: (p) => _openDetail(p, players),
          duplicatedNames: duplicated,
        );
      },
    );
  }

  // ── TAB 2: RANKING ANUAL ──────────────────────────────────────────────────
  Widget _buildAnnualTab() {
    return Column(children: [
      _yearSelector(),
      Expanded(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs').doc(widget.clubId)
              .collection('annual_stats').doc(_selectedYear.toString())
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kAccentGreen));
            }
            if (snap.hasError) return _emptyState('Error: ${snap.error}');
            if (!snap.hasData || !snap.data!.exists) {
              return _emptyState('No hay ranking publicado para $_selectedYear.');
            }

            final raw = (snap.data!.data() as Map<String, dynamic>)['players'];
            if (raw is! List || raw.isEmpty) {
              return _emptyState('No hay ranking publicado para $_selectedYear.');
            }

            final players = (raw as List)
                .map((p) => PlayerStats.fromMap(Map<String, dynamic>.from(p)))
                .toList();

            final nameCounts = <String, int>{};
            for (var p in players) nameCounts[p.name] = (nameCounts[p.name] ?? 0) + 1;
            final duplicated = nameCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

            final sorted = _sortPlayers(players, _sortColA, _sortAscA);

            return _buildTable(
              players: sorted,
              cols: _colsAnnual,
              widths: _widthsAnnual,
              sortCol: _sortColA,
              sortAsc: _sortAscA,
              showResult: false,
              showTournaments: true,
              onSort: (i) => setState(() {
                if (_sortColA == i) { _sortAscA = !_sortAscA; }
                else { _sortColA = i; _sortAscA = false; }
              }),
              onTapRow: (p) => _openDetail(p, sorted),
              duplicatedNames: duplicated,
            );
          },
        ),
      ),
    ]);
  }

  Widget _yearSelector() {
    final years = List.generate(5, (i) => DateTime.now().year - i);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Text('AÑO', style: GoogleFonts.inter(
            color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: _kCardBg,
          style: GoogleFonts.inter(color: _kAccentGreen, fontSize: 12, fontWeight: FontWeight.bold),
          underline: const SizedBox(),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
          onChanged: (y) { if (y != null) setState(() => _selectedYear = y); },
        ),
      ]),
    );
  }

  // ── TABLA ─────────────────────────────────────────────────────────────────
  Widget _buildTable({
    required List<PlayerStats> players,
    required List<String>  cols,
    required List<double>  widths,
    required int           sortCol,
    required bool          sortAsc,
    required bool          showResult,
    required bool          showTournaments,
    required void Function(int) onSort,
    required void Function(PlayerStats) onTapRow,
    required Set<String>   duplicatedNames,
  }) {
    final maxPts = players.isEmpty ? 0
        : players.map((p) => p.rankingPts).reduce((a, b) => a > b ? a : b);

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TableHeader(
                    cols: cols, widths: widths,
                    sortCol: sortCol, sortAsc: sortAsc, onSort: onSort,
                  ),
                  const SizedBox(height: 4),
                  ...players.asMap().entries.expand((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return [
                      _TableRow(
                        rank: i + 1, player: p, widths: widths,
                        showResult: showResult, showTournaments: showTournaments,
                        isLeader: p.rankingPts == maxPts && maxPts > 0,
                        onTap: () => onTapRow(p),
                        duplicatedNames: duplicatedNames,
                        cols: cols,
                      ),
                      const SizedBox(height: 4),
                    ];
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
            const SizedBox(height: 200),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      color: _kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        collapsedIconColor: _kAccentGreen,
        iconColor: _kAccentGreen,
        title: Text('CRITERIOS Y SIGNIFICADOS',
            style: GoogleFonts.exo2(color: _kTextPrimary, fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legendTitle('CRITERIO DE ORDEN'),
              _legendText('• Ordenado por mayor puntaje (PTS). Empate: %G → %S → %J.'),
              const SizedBox(height: 8),
              _legendTitle('RESULTADOS'),
              for (final r in ['winner', 'runnerUp', 'semi', 'quarter', 'r16', 'r32', 'r1'])
                _legendResultRow(r),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _legendTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(t, style: GoogleFonts.inter(
        color: _kAccentGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _legendText(String t) => Text(t,
      style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 10, height: 1.4));

  Widget _legendResultRow(String result) {
    final cfg = _resultCfg(result);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: cfg.color, borderRadius: BorderRadius.circular(4)),
          child: Text(cfg.label,
              style: GoogleFonts.inter(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(_resultDescription(result),
            style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 10))),
      ]),
    );
  }

  String _resultDescription(String r) {
    switch (r) {
      case 'winner':   return 'Ganó el torneo';
      case 'runnerUp': return 'Perdió la final';
      case 'semi':     return 'Eliminado en Semifinal';
      case 'quarter':  return 'Eliminado en Cuartos';
      case 'r16':      return 'Eliminado en Octavos';
      case 'r32':      return 'Eliminado en Dieciseisavos';
      default:         return 'Primera ronda';
    }
  }

  // ── ORDENAR ───────────────────────────────────────────────────────────────
  List<PlayerStats> _sortPlayers(List<PlayerStats> list, int col, bool asc) {
    final sorted = List<PlayerStats>.from(list);
    int Function(PlayerStats, PlayerStats) cmp;
    switch (col) {
      case 2:  cmp = (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()); break;
      case 3:  cmp = (a, b) => _cmpResult(a.result, b.result); break;
      case 4:  cmp = (a, b) => a.pj.compareTo(b.pj); break;
      case 5:  cmp = (a, b) => a.pg.compareTo(b.pg); break;
      case 6:  cmp = (a, b) => a.pp.compareTo(b.pp); break;
      case 7:  cmp = (a, b) => a.pctGames.compareTo(b.pctGames); break;
      case 8:  cmp = (a, b) => a.setsG.compareTo(b.setsG); break;
      case 9:  cmp = (a, b) => a.setsP.compareTo(b.setsP); break;
      case 10: cmp = (a, b) => a.pctSets.compareTo(b.pctSets); break;
      case 11: cmp = (a, b) => a.gamesG.compareTo(b.gamesG); break;
      case 12: cmp = (a, b) => a.gamesP.compareTo(b.gamesP); break;
      case 13: cmp = (a, b) => a.pctGamesIndividual.compareTo(b.pctGamesIndividual); break;
      case 15: cmp = (a, b) => a.streak.compareTo(b.streak); break;
      case 16: cmp = (a, b) => a.tournaments.length.compareTo(b.tournaments.length); break;
      default: cmp = (a, b) => a.rankingPts.compareTo(b.rankingPts); break;
    }
    sorted.sort((a, b) => asc ? cmp(a, b) : cmp(b, a));
    return sorted;
  }

  int _cmpResult(String r1, String r2) {
    const order = ['r1', 'r32', 'r16', 'quarter', 'semi', 'runnerUp', 'winner'];
    return order.indexOf(r1).compareTo(order.indexOf(r2));
  }

  // ── FAB ADMIN ─────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments').doc(widget.tournamentId).snapshots(),
      builder: (ctx, snap) {
        final published = snap.data?.data() is Map
            ? (snap.data!.data() as Map)['publishedToAnnual'] == true
            : false;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'pub',
              backgroundColor: published ? Colors.redAccent.withAlpha(200) : _kAccentGreen,
              foregroundColor: published ? Colors.white : Colors.black,
              icon: Icon(published ? Icons.unpublished_outlined : Icons.publish_rounded, size: 18),
              label: Text(
                published ? 'RETIRAR RANKING' : 'PUBLICAR RANKING',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              onPressed: () => published ? _unpublish() : _publish(),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'cfg',
              backgroundColor: _kCardBg,
              foregroundColor: _kTextSecondary,
              elevation: 2,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: Text('CONFIG PUNTOS',
                  style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1)),
              onPressed: _openConfig,
            ),
          ],
        );
      },
    );
  }

  void _openConfig() {
    showDialog(
      context: context,
      builder: (_) => RankingConfigModal(
        initial: _localRankingConfig,
        onSaved: (cfg) {
          setState(() => _localRankingConfig = cfg);
          widget.onConfigSaved(cfg);
          _recalcWithConfig(cfg);
        },
      ),
    );
  }

  /// FIX CRÍTICO: lee los slots de temp_layout/current y construye el
  /// BracketLayoutInfo directamente desde los slots + tournamentId,
  /// sin intentar leer 'layoutInfo' (que nunca se guarda ahí).
  Future<void> _recalcWithConfig(RankingConfig cfg) async {
    final snap = await FirebaseFirestore.instance
        .collection('tournaments').doc(widget.tournamentId)
        .collection('temp_layout').doc('current').get();

    if (!snap.exists || snap.data() == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orangeAccent,
            content: Text('No hay fixture cargado aún.',
                style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
      return;
    }

    final rawSlots = (snap.data()!['slots'] as Map<String, dynamic>?) ?? {};
    final slots = rawSlots.map(
      (k, v) => MapEntry(int.tryParse(k) ?? 0, Map<String, dynamic>.from(v as Map)),
    );

    // Reconstruir BracketLayoutInfo desde el tournamentDoc (playerCount)
    final tDoc = await FirebaseFirestore.instance
        .collection('tournaments').doc(widget.tournamentId).get();
    final playerCount = (tDoc.data()?['playerCount'] ?? 16) as int;

    final layoutInfo = _buildLayoutInfoFromPlayerCount(playerCount);

    await StatsCalculator.recalculate(
      tournamentId:  widget.tournamentId,
      slots:         slots,
      layoutInfo:    layoutInfo,
      rankingConfig: cfg,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kAccentGreen,
          content: Text('Puntos recalculados.',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  /// Reconstruye un BracketLayoutInfo minimal a partir del playerCount.
  /// Espeja la lógica de BracketLayout._compute() sin depender de widgets.
  BracketLayoutInfo _buildLayoutInfoFromPlayerCount(int playerCount) {
    // Normalizar a potencia de 2
    int pc = 4;
    for (final v in [4, 8, 16, 32]) { if (v >= playerCount) { pc = v; break; } }

    final totalRounds = (pc == 4 ? 2 : pc == 8 ? 3 : pc == 16 ? 4 : 5);
    final matches = <MatchInfo>[];

    int offset = 0;
    int size   = pc;

    for (int r = 0; r < totalRounds; r++) {
      final isFinal = r == totalRounds - 1;
      final count   = size ~/ 2;
      for (int i = 0; i < count; i++) {
        final p1   = offset + i * 2;
        final p2   = p1 + 1;
        final next = isFinal ? -1 : offset + size + i;
        matches.add(MatchInfo(slotP1: p1, slotP2: p2, nextSlot: next, round: r, isFinal: isFinal));
      }
      offset += size;
      size   ~/= 2;
    }

    return BracketLayoutInfo(totalRounds: totalRounds, matches: matches);
  }

  Future<void> _publish() async {
    await StatsCalculator.publishToAnnual(
      clubId:         widget.clubId,
      tournamentId:   widget.tournamentId,
      tournamentName: widget.tournamentName,
      year:           _selectedYear,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _kAccentGreen,
        content: Text('Publicado en ranking $_selectedYear',
            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
      ));
    }
  }

  Future<void> _unpublish() async {
    await StatsCalculator.unpublishFromAnnual(
      clubId:       widget.clubId,
      tournamentId: widget.tournamentId,
      year:         _selectedYear,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Retirado del ranking anual',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ));
    }
  }

  void _openDetail(PlayerStats player, List<PlayerStats> allPlayers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlayerDetailSheet(
        player:     player,
        allPlayers: allPlayers,
        clubId:     widget.clubId,
        year:       _selectedYear,
      ),
    );
  }

  Widget _emptyState(String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.bar_chart_rounded, color: Colors.white12, size: 48),
      const SizedBox(height: 12),
      Text(msg, style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final List<String> cols;
  final List<double> widths;
  final int sortCol;
  final bool sortAsc;
  final void Function(int) onSort;

  const _TableHeader({
    required this.cols, required this.widths,
    required this.sortCol, required this.sortAsc, required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: List.generate(cols.length, (i) {
          final isActive = sortCol == i;
          return GestureDetector(
            onTap: () => onSort(i),
            child: Tooltip(
              message: _TournamentStatsScreenState._colTooltips[cols[i]] ?? cols[i],
              child: SizedBox(
                width: widths[i],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cols[i],
                        style: GoogleFonts.inter(
                          color: isActive ? _kAccentGreen : Colors.white60,
                          fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center),
                    if (isActive)
                      Icon(sortAsc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: _kAccentGreen, size: 16),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _TableRow extends StatelessWidget {
  final int rank;
  final PlayerStats player;
  final List<double> widths;
  final List<String> cols;
  final bool showResult;
  final bool showTournaments;
  final bool isLeader;
  final VoidCallback onTap;
  final Set<String> duplicatedNames;

  const _TableRow({
    required this.rank, required this.player, required this.widths,
    required this.cols, required this.showResult, required this.showTournaments,
    required this.isLeader, required this.onTap, required this.duplicatedNames,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (duplicatedNames.contains(player.name) && player.dni != null)
        ? '${player.name} (${player.dni})'
        : player.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isLeader ? _kAccentGreen.withAlpha(40) : _kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          // Rank
          SizedBox(width: widths[0],
              child: Text(rank.toString(),
                  style: GoogleFonts.azeretMono(
                      color: isLeader ? Colors.black : Colors.white,
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          // Avatar
          SizedBox(width: widths[1],
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(13),
                  border: Border.all(
                      color: _kAccentGreen.withAlpha(isLeader ? 200 : 77), width: 1),
                  image: player.photoUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(player.photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: player.photoUrl.isEmpty
                    ? Icon(Icons.person, size: 16, color: Colors.white.withAlpha(77))
                    : null,
              )),
          // Nombre
          SizedBox(width: widths[2],
              child: Text(displayName.toUpperCase(),
                  style: GoogleFonts.inter(
                      color: isLeader ? Colors.black : Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
          // Columnas dinámicas
          ..._buildCells(),
        ]),
      ),
    );
  }

  List<Widget> _buildCells() {
    final List<Widget> cells = [];
    final valueColor = isLeader ? Colors.black : Colors.white;
    final monoStyle  = GoogleFonts.azeretMono(color: valueColor, fontSize: 11);
    final ptsStyle   = GoogleFonts.azeretMono(
        color: isLeader ? Colors.black : _kAccentGreen,
        fontSize: 11, fontWeight: FontWeight.bold);

    for (int i = 3; i < cols.length; i++) {
      final col   = cols[i];
      final width = widths[i];
      Widget cell;

      switch (col) {
        case 'RESULT':
          cell = _ResultChip(player.result);
          break;
        case 'PJ':  cell = Text(player.pj.toString(),  style: monoStyle, textAlign: TextAlign.center); break;
        case 'PG':  cell = Text(player.pg.toString(),  style: monoStyle, textAlign: TextAlign.center); break;
        case 'PP':  cell = Text(player.pp.toString(),  style: monoStyle, textAlign: TextAlign.center); break;
        case '%G':  cell = Text('${player.pctGames.toStringAsFixed(0)}%',  style: monoStyle, textAlign: TextAlign.center); break;
        case 'SG':  cell = Text(player.setsG.toString(), style: monoStyle, textAlign: TextAlign.center); break;
        case 'SP':  cell = Text(player.setsP.toString(), style: monoStyle, textAlign: TextAlign.center); break;
        case '%S':  cell = Text('${player.pctSets.toStringAsFixed(0)}%',   style: monoStyle, textAlign: TextAlign.center); break;
        case 'GG':  cell = Text(player.gamesG.toString(), style: monoStyle, textAlign: TextAlign.center); break;
        case 'GP':  cell = Text(player.gamesP.toString(), style: monoStyle, textAlign: TextAlign.center); break;
        case '%J':  cell = Text('${player.pctGamesIndividual.toStringAsFixed(0)}%', style: monoStyle, textAlign: TextAlign.center); break;
        case 'PTS': cell = Text(player.rankingPts.toString(), style: ptsStyle, textAlign: TextAlign.center); break;
        case 'RACHA':
          cell = player.streak > 0
              ? Icon(
                  player.streakType == 'W'
                      ? Icons.local_fire_department_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: player.streakType == 'W' ? Colors.greenAccent : Colors.redAccent,
                )
              : Text('---', style: monoStyle, textAlign: TextAlign.center);
          break;
        case 'TORNEOS':
          cell = Text(player.tournaments.length.toString(), style: monoStyle, textAlign: TextAlign.center);
          break;
        default:
          cell = const SizedBox.shrink();
      }

      cells.add(SizedBox(width: width, child: cell));
    }
    return cells;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _ResultChip extends StatelessWidget {
  final String result;
  const _ResultChip(this.result);

  @override
  Widget build(BuildContext context) {
    final cfg = _resultCfg(result);
    final isDark = cfg.color == const Color(0xFF303030) || cfg.color == const Color(0xFF505050);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cfg.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(cfg.label,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black,
            fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: config de resultado (compartido con player_detail_sheet via función top-level)
// ─────────────────────────────────────────────────────────────────────────────
class _ResultConfig {
  final String label;
  final String icon;
  final Color  color;
  const _ResultConfig(this.label, this.icon, this.color);
}

_ResultConfig _resultCfg(String result) {
  switch (result) {
    case 'winner':   return const _ResultConfig('CAMPEÓN',   '🏆', Color(0xFFFFD700));
    case 'runnerUp': return const _ResultConfig('FINALISTA', '🥈', Color(0xFFC0C0C0));
    case 'semi':     return const _ResultConfig('SEMI',      '🥉', Color(0xFFCD7F32));
    case 'quarter':  return const _ResultConfig('CUARTOS',   '●',  Color(0xFFA0A0A0));
    case 'r16':      return const _ResultConfig('8AVOS',     '●',  Color(0xFF707070));
    case 'r32':      return const _ResultConfig('16AVOS',    '●',  Color(0xFF505050));
    default:         return const _ResultConfig('R1',        '●',  Color(0xFF303030));
  }
}
