import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stats_calculator.dart';
// Importamos _resultCfg de tournament_stats_screen
// NOTA: _ResultConfig y _resultCfg son top-level en tournament_stats_screen.dart,
// por lo tanto accesibles desde aquí sin prefijo al estar en el mismo package.

// ─────────────────────────────────────────────────────────────────────────────
// COLORES — definidos acá para uso interno del sheet.
// Usamos las mismas constantes de valor pero con nombres propios del archivo.
// ─────────────────────────────────────────────────────────────────────────────
const Color _sheetBg            = Color(0xFF0A0F1E);
const Color _sheetCard          = Color(0xFF12172B);
const Color _sheetGreen         = Color(0xFF00FF41);
const Color _sheetBlue          = Color(0xFF0085C7);
const Color _sheetTextPrimary   = Colors.white;
const Color _sheetTextSecondary = Colors.white70;

class PlayerDetailSheet extends StatefulWidget {
  final PlayerStats       player;
  final List<PlayerStats> allPlayers;
  final String            clubId;
  final int               year;

  const PlayerDetailSheet({
    super.key,
    required this.player,
    required this.allPlayers,
    required this.clubId,
    required this.year,
  });

  @override
  State<PlayerDetailSheet> createState() => _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends State<PlayerDetailSheet> {
  PlayerStats? _h2hRival;
  final GlobalKey _repaintKey = GlobalKey();

  _H2HResult? get _h2h =>
      _h2hRival == null ? null : _computeH2H(widget.player, _h2hRival!);

  _H2HResult _computeH2H(PlayerStats a, PlayerStats b) {
    final aTourneys = a.tournaments.map((t) => t.id).toSet();
    final bTourneys = b.tournaments.map((t) => t.id).toSet();
    final common    = aTourneys.intersection(bTourneys);

    int winsA = 0, winsB = 0;
    const order = ['r1', 'r32', 'r16', 'quarter', 'semi', 'runnerUp', 'winner'];
    final history = <_H2HTournamentMatch>[];

    for (final tid in common) {
      final tA = a.tournaments.firstWhere((t) => t.id == tid);
      final tB = b.tournaments.firstWhere((t) => t.id == tid);
      final rankA = order.indexOf(tA.result);
      final rankB = order.indexOf(tB.result);

      String result;
      if      (rankA > rankB) { winsA++; result = '${a.name} ganó'; }
      else if (rankB > rankA) { winsB++; result = '${b.name} ganó'; }
      else                    { result = 'Empate'; }

      history.add(_H2HTournamentMatch(tournamentName: tA.name, result: result));
    }

    return _H2HResult(
      playerA: a.name, playerB: b.name,
      winsA: winsA, winsB: winsB,
      commonTournaments: common.length,
      matchHistory: history,
    );
  }

  Future<void> _export() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image    = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir   = await getTemporaryDirectory();
      final file  = File('${dir.path}/stats_${widget.player.nameKey}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Estadísticas de ${widget.player.name} — ${widget.year}',
      );
    } catch (e) {
      debugPrint('Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, ctrl) => RepaintBoundary(
        key: _repaintKey,
        child: Container(
          decoration: const BoxDecoration(
            color: _sheetCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            _buildToolbar(p),
            Expanded(child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _buildHeader(p),
                const SizedBox(height: 16),
                _buildStatsCards(p),
                const SizedBox(height: 16),
                if (p.tournaments.isNotEmpty) ...[
                  _sectionTitle('HISTORIAL DE TORNEOS'),
                  const SizedBox(height: 8),
                  _buildHistory(p),
                  const SizedBox(height: 16),
                ],
                _sectionTitle('HEAD TO HEAD'),
                const SizedBox(height: 8),
                _buildH2H(p),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildToolbar(PlayerStats p) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      Text(p.name.toUpperCase(),
          style: GoogleFonts.exo2(
              color: _sheetTextPrimary, fontSize: 13,
              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const Spacer(),
      GestureDetector(
        onTap: _export,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _sheetGreen.withAlpha(80)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.ios_share_rounded, color: _sheetGreen, size: 13),
            const SizedBox(width: 5),
            Text('EXPORTAR',
                style: GoogleFonts.inter(color: _sheetGreen, fontSize: 9,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildHeader(PlayerStats p) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _sheetCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withAlpha(15)),
    ),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(10),
          border: Border.all(color: _sheetGreen.withAlpha(60), width: 1.5),
          image: p.photoUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(p.photoUrl), fit: BoxFit.cover)
              : null,
        ),
        child: p.photoUrl.isEmpty
            ? Icon(Icons.person, size: 28, color: Colors.white.withAlpha(38))
            : null,
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name.toUpperCase(),
              style: GoogleFonts.exo2(
                  color: _sheetTextPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          if (p.dni != null && p.dni!.isNotEmpty)
            Text('DNI: ${p.dni}',
                style: GoogleFonts.inter(color: _sheetTextSecondary, fontSize: 10)),
          const SizedBox(height: 4),
          Row(children: [
            _resultPill(p.result),
            const SizedBox(width: 8),
            if (p.streak != 0) _streakPill(p.streak, p.streakType),
          ]),
        ],
      )),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p.rankingPts.toString(),
            style: GoogleFonts.azeretMono(
                color: _sheetGreen, fontSize: 28, fontWeight: FontWeight.bold)),
        Text('PTS', style: GoogleFonts.inter(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
      ]),
    ]),
  );

  Widget _resultPill(String result) {
    final cfg = _resultCfg(result);
    final isDark = cfg.color == const Color(0xFF303030) || cfg.color == const Color(0xFF505050);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cfg.color.withAlpha(100), width: 0.5),
      ),
      child: Text('${cfg.icon} ${cfg.label}',
          style: GoogleFonts.inter(
              color: isDark ? _sheetTextSecondary : Colors.black,
              fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _streakPill(int streak, String type) {
    final isW  = type == 'W';
    final color = isW ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isW ? Icons.local_fire_department_rounded : Icons.arrow_downward_rounded,
          color: color, size: 12,
        ),
        const SizedBox(width: 4),
        Text('$streak${type} EN RACHA',
            style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildStatsCards(PlayerStats p) {
    return Row(children: [
      Expanded(child: _statsCard('PARTIDOS', [
        _StatRow('Jugados',   p.pj.toString()),
        _StatRow('Ganados',   p.pg.toString(), color: Colors.greenAccent),
        _StatRow('Perdidos',  p.pp.toString(), color: Colors.redAccent),
        _StatRow('% Victoria','${p.pctGames.toStringAsFixed(0)}%', color: _pctColor(p.pctGames)),
      ])),
      const SizedBox(width: 8),
      Expanded(child: _statsCard('SETS', [
        _StatRow('Ganados',  p.setsG.toString(), color: Colors.greenAccent),
        _StatRow('Perdidos', p.setsP.toString(), color: Colors.redAccent),
        _StatRow('Total',    (p.setsG + p.setsP).toString()),
        _StatRow('% Sets',   '${p.pctSets.toStringAsFixed(0)}%', color: _pctColor(p.pctSets)),
      ])),
      const SizedBox(width: 8),
      Expanded(child: _statsCard('GAMES', [
        _StatRow('Ganados',  p.gamesG.toString(), color: Colors.greenAccent),
        _StatRow('Perdidos', p.gamesP.toString(), color: Colors.redAccent),
        _StatRow('Total',    (p.gamesG + p.gamesP).toString()),
        _StatRow('% Games',  '${p.pctGamesIndividual.toStringAsFixed(0)}%', color: _pctColor(p.pctGamesIndividual)),
      ])),
    ]);
  }

  Widget _statsCard(String title, List<_StatRow> rows) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _sheetCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withAlpha(12)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.exo2(
          color: _sheetBlue, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
      const SizedBox(height: 8),
      ...rows.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(r.label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
            Text(r.value, style: GoogleFonts.azeretMono(
                color: r.color ?? Colors.white70,
                fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      )),
    ]),
  );

  Color _pctColor(double v) {
    if (v >= 60) return Colors.greenAccent;
    if (v >= 40) return Colors.white70;
    return Colors.redAccent;
  }

  Widget _buildHistory(PlayerStats p) => Column(
    children: p.tournaments.map((t) {
      final cfg    = _resultCfg(t.result);
      final isDark = cfg.color == const Color(0xFF303030) || cfg.color == const Color(0xFF505050);
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _sheetCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(12)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cfg.color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(cfg.icon, style: GoogleFonts.inter(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: GoogleFonts.inter(
                color: _sheetTextPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
            Text(cfg.label, style: GoogleFonts.inter(
                color: isDark ? _sheetTextSecondary : Colors.black,
                fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _sheetGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('+${t.pts} PTS',
                style: GoogleFonts.azeretMono(
                    color: _sheetGreen, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ]),
      );
    }).toList(),
  );

  Widget _buildH2H(PlayerStats p) {
    final rivals = widget.allPlayers.where((r) => r.nameKey != p.nameKey).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sheetCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('VS', style: GoogleFonts.inter(
              color: Colors.white.withAlpha(20), fontSize: 10, letterSpacing: 2)),
          const SizedBox(width: 12),
          Expanded(child: DropdownButton<PlayerStats>(
            value: _h2hRival,
            hint: Text('Seleccionar rival',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
            dropdownColor: _sheetCard,
            style: GoogleFonts.inter(color: _sheetTextPrimary, fontSize: 11),
            isExpanded: true,
            underline: Container(height: 0.5, color: Colors.white24),
            items: rivals.map((r) => DropdownMenuItem(
              value: r,
              child: Text(r.name.toUpperCase()),
            )).toList(),
            onChanged: (r) => setState(() => _h2hRival = r),
          )),
        ]),
        if (_h2h != null) ...[
          const SizedBox(height: 16),
          _buildH2HResult(_h2h!),
        ] else ...[
          const SizedBox(height: 12),
          Center(child: Text('Seleccioná un rival para ver el historial',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 10))),
        ],
      ]),
    );
  }

  Widget _buildH2HResult(_H2HResult h2h) {
    final total = h2h.winsA + h2h.winsB;
    final pctA  = total == 0 ? 0.5 : h2h.winsA / total;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(h2h.playerA.toUpperCase(),
            style: GoogleFonts.exo2(color: _sheetTextPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis)),
        Text('VS', style: GoogleFonts.inter(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
        Expanded(child: Text(h2h.playerB.toUpperCase(),
            textAlign: TextAlign.right,
            style: GoogleFonts.exo2(color: _sheetTextPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text(h2h.winsA.toString(),
            style: GoogleFonts.azeretMono(color: _sheetGreen, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pctA,
            backgroundColor: Colors.redAccent.withAlpha(60),
            valueColor: const AlwaysStoppedAnimation(_sheetGreen),
            minHeight: 8,
          ),
        )),
        const SizedBox(width: 10),
        Text(h2h.winsB.toString(),
            style: GoogleFonts.azeretMono(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Center(child: Text(
        '${h2h.commonTournaments} torneo${h2h.commonTournaments != 1 ? 's' : ''} en común',
        style: GoogleFonts.inter(color: Colors.white24, fontSize: 9, letterSpacing: 1),
      )),
      const SizedBox(height: 16),
      _sectionTitle('HISTORIAL POR TORNEO'),
      const SizedBox(height: 8),
      ...h2h.matchHistory.map((m) {
        Color textColor = _sheetTextPrimary;
        if (m.result.contains(widget.player.name))         textColor = _sheetGreen;
        else if (_h2hRival != null && m.result.contains(_h2hRival!.name)) textColor = Colors.redAccent;
        else if (m.result == 'Empate')                     textColor = _sheetTextSecondary;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _sheetCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(m.tournamentName,
                  style: GoogleFonts.inter(color: _sheetTextPrimary, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
              Text(m.result,
                  style: GoogleFonts.inter(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
    ]);
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: GoogleFonts.exo2(
        color: _sheetBlue, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT CONFIG — definida localmente para no depender de tournament_stats_screen
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

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow {
  final String label;
  final String value;
  final Color? color;
  const _StatRow(this.label, this.value, {this.color});
}

class _H2HResult {
  final String playerA;
  final String playerB;
  final int    winsA;
  final int    winsB;
  final int    commonTournaments;
  final List<_H2HTournamentMatch> matchHistory;

  const _H2HResult({
    required this.playerA, required this.playerB,
    required this.winsA,   required this.winsB,
    required this.commonTournaments,
    required this.matchHistory,
  });
}

class _H2HTournamentMatch {
  final String tournamentName;
  final String result;
  const _H2HTournamentMatch({required this.tournamentName, required this.result});
}