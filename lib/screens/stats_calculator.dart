import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE ESTADÍSTICAS DE JUGADOR
// ─────────────────────────────────────────────────────────────────────────────
class PlayerStats {
  final String nameKey;
  final String name;
  final String phone;
  final String? dni;
  final String photoUrl;

  int pj;
  int pg;
  int pp;
  int setsG;
  int setsP;
  int gamesG;
  int gamesP;
  int rankingPts;
  String result;
  int streak;
  String streakType;

  List<TournamentEntry> tournaments = [];

  PlayerStats({
    required this.nameKey,
    required this.name,
    required this.phone,
    this.dni,
    required this.photoUrl,
    this.pj = 0,
    this.pg = 0,
    this.pp = 0,
    this.setsG = 0,
    this.setsP = 0,
    this.gamesG = 0,
    this.gamesP = 0,
    this.rankingPts = 0,
    this.result = 'r1',
    this.streak = 0,
    this.streakType = '',
  });

  double get pctGames => pj == 0 ? 0 : (pg / pj * 100);
  double get pctSets  => (setsG + setsP) == 0 ? 0 : (setsG / (setsG + setsP) * 100);
  double get pctGamesIndividual =>
      (gamesG + gamesP) == 0 ? 0 : (gamesG / (gamesG + gamesP) * 100);

  Map<String, dynamic> toMap() => {
    'nameKey':    nameKey,
    'name':       name,
    'phone':      phone,
    'dni':        dni,
    'photoUrl':   photoUrl,
    'pj':         pj,
    'pg':         pg,
    'pp':         pp,
    'setsG':      setsG,
    'setsP':      setsP,
    'pctSets':    double.parse(pctSets.toStringAsFixed(1)),
    'gamesG':     gamesG,
    'gamesP':     gamesP,
    'pctGames':   double.parse(pctGames.toStringAsFixed(1)),
    'pctGamesIndividual': double.parse(pctGamesIndividual.toStringAsFixed(1)),
    'rankingPts': rankingPts,
    'result':     result,
    'streak':     streak,
    'streakType': streakType, // FIX: era 'streakType': streak (guardaba int en lugar de String)
    'tournaments': tournaments.map((t) => t.toMap()).toList(),
  };

  static PlayerStats fromMap(Map<String, dynamic> m) => PlayerStats(
    nameKey:    m['nameKey']    ?? '',
    name:       m['name']       ?? '',
    phone:      m['phone']      ?? '',
    dni:        m['dni'],
    photoUrl:   m['photoUrl']   ?? '',
    pj:         m['pj']         ?? 0,
    pg:         m['pg']         ?? 0,
    pp:         m['pp']         ?? 0,
    setsG:      m['setsG']      ?? 0,
    setsP:      m['setsP']      ?? 0,
    gamesG:     m['gamesG']     ?? 0,
    gamesP:     m['gamesP']     ?? 0,
    rankingPts: m['rankingPts'] ?? 0,
    result:     m['result']     ?? 'r1',
    streak:     m['streak']     ?? 0,
    streakType: m['streakType'] is String ? m['streakType'] : '', // FIX: cast seguro
  )..tournaments = _parseTournaments(m['tournaments']);

  static List<TournamentEntry> _parseTournaments(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((t) => TournamentEntry(
      id:     t['id']     ?? '',
      name:   t['name']   ?? '',
      pts:    t['pts']    ?? 0,
      result: t['result'] ?? 'r1',
    )).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOURNAMENT ENTRY
// ─────────────────────────────────────────────────────────────────────────────
class TournamentEntry {
  final String id;
  final String name;
  final int    pts;
  final String result;

  const TournamentEntry({
    required this.id,
    required this.name,
    required this.pts,
    required this.result,
  });

  Map<String, dynamic> toMap() => {
    'id':     id,
    'name':   name,
    'pts':    pts,
    'result': result,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURACIÓN DE PUNTOS DE RANKING
// ─────────────────────────────────────────────────────────────────────────────
class RankingConfig {
  final int winner;
  final int runnerUp;
  final int semi;
  final int quarter;
  final int r16;
  final int r32;
  final int r1;

  const RankingConfig({
    this.winner   = 100,
    this.runnerUp = 60,
    this.semi     = 40,
    this.quarter  = 20,
    this.r16      = 15,
    this.r32      = 10,
    this.r1       = 5,
  });

  int ptsForResult(String result) {
    switch (result) {
      case 'winner':   return winner;
      case 'runnerUp': return runnerUp;
      case 'semi':     return semi;
      case 'quarter':  return quarter;
      case 'r16':      return r16;
      case 'r32':      return r32;
      default:         return r1;
    }
  }

  Map<String, dynamic> toMap() => {
    'winner':   winner,
    'runnerUp': runnerUp,
    'semi':     semi,
    'quarter':  quarter,
    'r16':      r16,
    'r32':      r32,
    'r1':       r1,
  };

  static RankingConfig fromMap(Map<String, dynamic>? m) {
    if (m == null) return const RankingConfig();
    return RankingConfig(
      winner:   m['winner']   ?? 100,
      runnerUp: m['runnerUp'] ?? 60,
      semi:     m['semi']     ?? 40,
      quarter:  m['quarter']  ?? 20,
      r16:      m['r16']      ?? 15,
      r32:      m['r32']      ?? 10,
      r1:       m['r1']       ?? 5,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO DEL LAYOUT (desacoplado de Flutter widgets)
// ─────────────────────────────────────────────────────────────────────────────
class BracketLayoutInfo {
  final int totalRounds;
  final List<MatchInfo> matches;

  const BracketLayoutInfo({
    required this.totalRounds,
    required this.matches,
  });
}

class MatchInfo {
  final int  slotP1;
  final int  slotP2;
  final int  nextSlot;
  final int  round;
  final bool isFinal;

  const MatchInfo({
    required this.slotP1,
    required this.slotP2,
    required this.nextSlot,
    required this.round,
    this.isFinal = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CALCULADOR DE ESTADÍSTICAS
// ─────────────────────────────────────────────────────────────────────────────
class StatsCalculator {

  static String playerKeyFull(String name, String? phone, String? dni) {
    final n = _normalize(name);
    final p = (phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final d = (dni   ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (d.isNotEmpty) return '$n|$d';
    if (p.isNotEmpty) return '$n|$p';
    return n;
  }

  static String _normalize(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
    const to   = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';
    var result = s.toLowerCase().trim();
    for (int i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  static Future<void> recalculate({
    required String tournamentId,
    required Map<int, Map<String, dynamic>> slots,
    required BracketLayoutInfo layoutInfo,
    required RankingConfig rankingConfig,
  }) async {
    debugPrint('[StatsCalculator] Recalculando torneo: $tournamentId');
    final stats = _computeFromSlots(slots, layoutInfo, rankingConfig);
    debugPrint('[StatsCalculator] ${stats.length} jugadores procesados');

    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('stats')
        .doc('summary')
        .set({
          'calculatedAt': FieldValue.serverTimestamp(),
          'players': stats.map((p) => p.toMap()).toList(),
        });
    debugPrint('[StatsCalculator] Stats guardadas en Firestore');
  }

  static List<PlayerStats> _computeFromSlots(
    Map<int, Map<String, dynamic>> slots,
    BracketLayoutInfo layoutInfo,
    RankingConfig rankingConfig,
  ) {
    final Map<String, PlayerStats> statsMap    = {};
    final Map<String, List<bool>>  matchHistory = {};
    final Map<String, String>      results      = {};

    // Registrar todos los jugadores presentes en slots
    for (final entry in slots.entries) {
      final data  = entry.value;
      final name  = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final phone = (data['phone'] ?? '').toString();
      final dni   = (data['dni']   ?? '').toString();
      final key   = playerKeyFull(name, phone, dni);
      if (!statsMap.containsKey(key)) {
        statsMap[key] = PlayerStats(
          nameKey:  key,
          name:     name,
          phone:    phone,
          dni:      dni.isNotEmpty ? dni : null,
          photoUrl: (data['photoUrl'] ?? '').toString(),
        );
        matchHistory[key] = [];
      }
    }

    // Procesar cada match del bracket
    for (final match in layoutInfo.matches) {
      final s1 = slots[match.slotP1];
      final s2 = slots[match.slotP2];
      if (s1 == null || s2 == null) continue;

      final n1 = (s1['name'] ?? '').toString().trim();
      final n2 = (s2['name'] ?? '').toString().trim();
      if (n1.isEmpty || n2.isEmpty) continue;

      final scores = (s1['score'] as List?) ?? [];
      if (scores.isEmpty) continue;

      final bool p1Won = s1['winner'] == true;

      final k1 = playerKeyFull(n1, (s1['phone'] ?? '').toString(), (s1['dni'] ?? '').toString());
      final k2 = playerKeyFull(n2, (s2['phone'] ?? '').toString(), (s2['dni'] ?? '').toString());

      statsMap.putIfAbsent(k1, () => PlayerStats(
        nameKey: k1, name: n1,
        phone: (s1['phone'] ?? '').toString(),
        dni: ((s1['dni'] ?? '').toString()).isNotEmpty ? (s1['dni'] ?? '').toString() : null,
        photoUrl: (s1['photoUrl'] ?? '').toString(),
      ));
      statsMap.putIfAbsent(k2, () => PlayerStats(
        nameKey: k2, name: n2,
        phone: (s2['phone'] ?? '').toString(),
        dni: ((s2['dni'] ?? '').toString()).isNotEmpty ? (s2['dni'] ?? '').toString() : null,
        photoUrl: (s2['photoUrl'] ?? '').toString(),
      ));

      final stat1 = statsMap[k1]!;
      final stat2 = statsMap[k2]!;

      stat1.pj++; stat2.pj++;
      if (p1Won) { stat1.pg++; stat2.pp++; }
      else       { stat1.pp++; stat2.pg++; }

      final parsed = _parseScores(scores);
      stat1.setsG  += parsed.setsP1;  stat1.setsP  += parsed.setsP2;
      stat2.setsG  += parsed.setsP2;  stat2.setsP  += parsed.setsP1;
      stat1.gamesG += parsed.gamesP1; stat1.gamesP += parsed.gamesP2;
      stat2.gamesG += parsed.gamesP2; stat2.gamesP += parsed.gamesP1;

      matchHistory.putIfAbsent(k1, () => []);
      matchHistory.putIfAbsent(k2, () => []);
      matchHistory[k1]!.add(p1Won);
      matchHistory[k2]!.add(!p1Won);

      final loserResult  = _resultForRound(match.round, layoutInfo.totalRounds);
      final winnerResult = _resultForAdvancing(match.round, layoutInfo.totalRounds);

      final loserKey  = p1Won ? k2 : k1;
      final winnerKey = p1Won ? k1 : k2;

      _updateIfBetter(results, loserKey, loserResult, layoutInfo.totalRounds);
      if (!match.isFinal) {
        _updateIfBetter(results, winnerKey, winnerResult, layoutInfo.totalRounds);
      }
    }

    // Asignar campeón y finalista desde la final
    for (final match in layoutInfo.matches) {
      if (!match.isFinal) continue;
      final s1     = slots[match.slotP1];
      final s2     = slots[match.slotP2];
      if (s1 == null || s2 == null) continue;
      final scores = (s1['score'] as List?) ?? [];
      if (scores.isEmpty) continue;
      final bool p1WonFinal = s1['winner'] == true;
      final n1 = (s1['name'] ?? '').toString().trim();
      final n2 = (s2['name'] ?? '').toString().trim();
      if (n1.isEmpty || n2.isEmpty) continue;
      final k1 = playerKeyFull(n1, (s1['phone'] ?? '').toString(), (s1['dni'] ?? '').toString());
      final k2 = playerKeyFull(n2, (s2['phone'] ?? '').toString(), (s2['dni'] ?? '').toString());
      results[p1WonFinal ? k1 : k2] = 'winner';
      _updateIfBetter(results, p1WonFinal ? k2 : k1, 'runnerUp', layoutInfo.totalRounds);
    }

    // Aplicar resultados y puntos
    for (final entry in results.entries) {
      if (statsMap.containsKey(entry.key)) {
        statsMap[entry.key]!.result = entry.value;
      }
    }
    for (final stat in statsMap.values) {
      stat.rankingPts = rankingConfig.ptsForResult(stat.result);
    }

    // Calcular rachas
    for (final entry in matchHistory.entries) {
      final key     = entry.key;
      final history = entry.value;
      if (history.isEmpty || !statsMap.containsKey(key)) continue;
      final lastResult = history.last;
      int streak = 0;
      for (int i = history.length - 1; i >= 0; i--) {
        if (history[i] == lastResult) streak++; else break;
      }
      statsMap[key]!.streak     = streak;
      statsMap[key]!.streakType = lastResult ? 'W' : 'L';
    }

    final list = statsMap.values.toList();
    list.sort((a, b) {
      final cmp = b.rankingPts.compareTo(a.rankingPts);
      if (cmp != 0) return cmp;
      return b.pctGames.compareTo(a.pctGames);
    });
    return list;
  }

  static _ParsedScore _parseScores(List scores) {
    int setsP1 = 0, setsP2 = 0, gamesP1 = 0, gamesP2 = 0;
    for (int i = 0; i < min(scores.length, 3); i++) {
      final parts = scores[i].toString().split('-');
      if (parts.length != 2) continue;
      final g1 = int.tryParse(parts[0]) ?? 0;
      final g2 = int.tryParse(parts[1]) ?? 0;
      // El 3er set solo cuenta si los primeros dos fueron 1-1
      if (i == 2 && setsP1 != 1) continue;
      gamesP1 += g1; gamesP2 += g2;
      if (g1 > g2) setsP1++; else if (g2 > g1) setsP2++;
    }
    return _ParsedScore(setsP1: setsP1, setsP2: setsP2, gamesP1: gamesP1, gamesP2: gamesP2);
  }

  static String _resultForRound(int round, int totalRounds) {
    switch (totalRounds - 1 - round) {
      case 0: return 'runnerUp';
      case 1: return 'semi';
      case 2: return 'quarter';
      case 3: return 'r16';
      case 4: return 'r32';
      default: return 'r1';
    }
  }

  static String _resultForAdvancing(int round, int totalRounds) {
    switch (totalRounds - 1 - (round + 1)) {
      case 0: return 'runnerUp';
      case 1: return 'semi';
      case 2: return 'quarter';
      case 3: return 'r16';
      case 4: return 'r32';
      default: return 'r1';
    }
  }

  static void _updateIfBetter(
    Map<String, String> results,
    String key,
    String newResult,
    int totalRounds,
  ) {
    const order = ['r1', 'r32', 'r16', 'quarter', 'semi', 'runnerUp', 'winner'];
    final current = results[key];
    if (current == null || order.indexOf(newResult) > order.indexOf(current)) {
      results[key] = newResult;
    }
  }

  // ── PUBLICAR AL RANKING ANUAL ─────────────────────────────────────────────
  static Future<void> publishToAnnual({
    required String clubId,
    required String tournamentId,
    required String tournamentName,
    required int year,
  }) async {
    final summaryDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('stats')
        .doc('summary')
        .get();

    if (!summaryDoc.exists) return;

    final rawPlayers = (summaryDoc.data()?['players'] as List?) ?? [];
    final tournamentStats = rawPlayers
        .map((p) => PlayerStats.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    final annualRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('annual_stats')
        .doc(year.toString());

    final annualSnap = await annualRef.get();
    final existing = <String, Map<String, dynamic>>{};

    if (annualSnap.exists) {
      final rawAnnual = (annualSnap.data()?['players'] as List?) ?? [];
      for (final p in rawAnnual) {
        final map = Map<String, dynamic>.from(p);
        final tournaments = (map['tournaments'] as List?) ?? [];
        map['tournaments'] = tournaments.where((t) => t['id'] != tournamentId).toList();
        existing[map['nameKey']] = map;
      }
    }

    for (final ts in tournamentStats) {
      final key = ts.nameKey;
      if (!existing.containsKey(key)) {
        existing[key] = {
          'nameKey':  ts.nameKey, 'name': ts.name,
          'phone':    ts.phone,   'dni':  ts.dni,
          'photoUrl': ts.photoUrl,
          'totalPts': 0,
          'pj': 0, 'pg': 0, 'pp': 0,
          'setsG': 0, 'setsP': 0,
          'gamesG': 0, 'gamesP': 0,
          'streak': 0, 'streakType': '',
          'tournaments': [],
        };
      }
      final ann = existing[key]!;
      ann['pj']       = (ann['pj']       ?? 0) + ts.pj;
      ann['pg']       = (ann['pg']       ?? 0) + ts.pg;
      ann['pp']       = (ann['pp']       ?? 0) + ts.pp;
      ann['setsG']    = (ann['setsG']    ?? 0) + ts.setsG;
      ann['setsP']    = (ann['setsP']    ?? 0) + ts.setsP;
      ann['gamesG']   = (ann['gamesG']   ?? 0) + ts.gamesG;
      ann['gamesP']   = (ann['gamesP']   ?? 0) + ts.gamesP;
      ann['totalPts'] = (ann['totalPts'] ?? 0) + ts.rankingPts;
      ann['streak']     = ts.streak;
      ann['streakType'] = ts.streakType;
      final tList = List<dynamic>.from(ann['tournaments'] ?? []);
      tList.add({'id': tournamentId, 'name': tournamentName, 'pts': ts.rankingPts, 'result': ts.result});
      ann['tournaments'] = tList;
    }

    await annualRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'players':   existing.values.toList(),
    });
    await FirebaseFirestore.instance
        .collection('tournaments').doc(tournamentId)
        .update({'publishedToAnnual': true});
  }

  static Future<void> unpublishFromAnnual({
    required String clubId,
    required String tournamentId,
    required int year,
  }) async {
    final annualRef = FirebaseFirestore.instance
        .collection('clubs').doc(clubId)
        .collection('annual_stats').doc(year.toString());

    final annualSnap = await annualRef.get();
    if (!annualSnap.exists) return;

    final rawAnnual = (annualSnap.data()?['players'] as List?) ?? [];
    final updated   = <Map<String, dynamic>>[];

    for (final p in rawAnnual) {
      final map   = Map<String, dynamic>.from(p);
      final tList = List<dynamic>.from(map['tournaments'] ?? []);
      final thisT = tList.firstWhere((t) => t['id'] == tournamentId, orElse: () => null);
      if (thisT != null) {
        final pts = thisT['pts'] ?? 0;
        map['totalPts']    = ((map['totalPts'] ?? 0) - pts).clamp(0, 999999);
        map['tournaments'] = tList.where((t) => t['id'] != tournamentId).toList();
      }
      if ((map['tournaments'] as List).isNotEmpty) updated.add(map);
    }

    await annualRef.set({'updatedAt': FieldValue.serverTimestamp(), 'players': updated});
    await FirebaseFirestore.instance
        .collection('tournaments').doc(tournamentId)
        .update({'publishedToAnnual': false});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER INTERNO
// ─────────────────────────────────────────────────────────────────────────────
class _ParsedScore {
  final int setsP1, setsP2, gamesP1, gamesP2;
  const _ParsedScore({
    required this.setsP1, required this.setsP2,
    required this.gamesP1, required this.gamesP2,
  });
}
