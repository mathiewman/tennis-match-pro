// =============================================================================
// PATCH ADICIONAL — stats_calculator.dart
// PlayerStats necesita el campo `tournaments` para PlayerDetailSheet.
// Agregar este campo a la clase PlayerStats existente:
// =============================================================================

// 1. En la clase PlayerStats, agregar el campo:
  List<TournamentEntry> tournaments = []; // ← agregar junto a los otros campos

// 2. Agregar la clase TournamentEntry al final de stats_calculator.dart:

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
}

// 3. En PlayerStats.fromMap(), agregar el parseo de tournaments:
//    (al final del método fromMap, antes del );)
//    ..tournaments = _parseTournaments(m['tournaments'])
//
//    Y agregar el helper estático en PlayerStats:

  static List<TournamentEntry> _parseTournaments(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((t) => TournamentEntry(
      id:     t['id']     ?? '',
      name:   t['name']   ?? '',
      pts:    t['pts']    ?? 0,
      result: t['result'] ?? 'r1',
    )).toList();
  }

// =============================================================================
// DEPENDENCIAS pubspec.yaml — agregar si no están:
// =============================================================================
//   share_plus: ^7.0.0
//   path_provider: ^2.0.0
