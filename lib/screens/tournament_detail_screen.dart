import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tournament_model.dart';
import '../services/push_notification_service.dart';
import 'tournament_pizarra_view_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOURNAMENT DETAIL SCREEN
// Muestra toda la info del torneo + lógica de inscripción del jugador.
// ─────────────────────────────────────────────────────────────────────────────
class TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;
  final Map<String, dynamic> data;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final uid               = FirebaseAuth.instance.currentUser?.uid ?? '';
    final name              = data['name']?.toString()             ?? 'TORNEO';
    final category          = data['category']?.toString()         ?? '';
    final cost              = (data['costoInscripcion'] ?? 0).toDouble();
    final sets              = data['setsPerMatch']                 ?? 3;
    final playerCount       = (data['playerCount'] ?? 16) as int;
    final status            = normalizeTournamentStatus(data['status']?.toString() ?? 'open');
    final promoUrl          = data['promoUrl']?.toString()         ?? '';
    final description       = data['description']?.toString()      ?? '';
    final clubId            = data['clubId']?.toString()           ?? '';
    final deadlineTs        = data['inscriptionDeadline'] as Timestamp?;
    final deadlineDate      = deadlineTs?.toDate();
    // ignore: unused_local_variable
    final isFree      = data['isFree'] as bool? ?? cost == 0;
    final gender      = data['gender']?.toString()    ?? '';
    final modality    = data['modality']?.toString()  ?? '';
    final premio      = data['premio']?.toString()    ?? '';
    final courtNames  = (data['courtNames'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final startDateTs = data['startDate'] as Timestamp?;
    final startDate   = startDateTs?.toDate();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar con imagen de promo ────────────────────────────────
          SliverAppBar(
            expandedHeight: promoUrl.isNotEmpty ? 240 : 160,
            pinned: true,
            backgroundColor: const Color(0xFF0B2218),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(children: [
                Positioned.fill(
                  child: promoUrl.isNotEmpty
                      ? Image.network(promoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _HeaderGradient(status: status))
                      : _HeaderGradient(status: status),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0A1F1A),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Contenido ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(name.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 10),

                  // Chips de estado
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip(category, Colors.white54),
                    _statusChip(status),
                    _chip('Al mejor de $sets sets', Colors.white38),
                    if (gender.isNotEmpty) _chip(gender, Colors.blueAccent.withOpacity(0.8)),
                    if (modality.isNotEmpty) _chip(modality, const Color(0xFFCCFF00).withOpacity(0.8)),
                  ]),
                  const SizedBox(height: 24),

                  // Cards de info
                  Row(children: [
                    Expanded(child: _infoCard(
                      Icons.payments_outlined,
                      'INSCRIPCIÓN',
                      cost > 0
                          ? '\$${NumberFormat('#,###').format(cost)}'
                          : 'GRATIS',
                      cost > 0
                          ? const Color(0xFFCCFF00)
                          : Colors.greenAccent,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _infoCard(
                      Icons.groups_outlined,
                      'CUPOS TOTALES',
                      '$playerCount jugadores',
                      Colors.white60,
                    )),
                  ]),

                  if (startDate != null || premio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      if (startDate != null)
                        Expanded(child: _infoCard(
                          Icons.event_available,
                          'FECHA DE INICIO',
                          DateFormat('dd/MM/yyyy').format(startDate),
                          Colors.white60,
                        )),
                      if (startDate != null && premio.isNotEmpty) const SizedBox(width: 12),
                      if (premio.isNotEmpty)
                        Expanded(child: _infoCard(
                          Icons.emoji_events_outlined,
                          'PREMIO',
                          premio,
                          Colors.orangeAccent,
                        )),
                    ]),
                  ],

                  if (courtNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('CANCHAS', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: courtNames.map((n) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFF00).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.25)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.sports_tennis, color: Color(0xFFCCFF00), size: 12),
                              const SizedBox(width: 5),
                              Text(n, style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          )).toList(),
                        ),
                      ]),
                    ),
                  ],

                  if (deadlineDate != null) ...[
                    const SizedBox(height: 12),
                    _deadlineCard(deadlineDate),
                  ],

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Text(description,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sección inscriptos con barra de cupos
                  _InscriptionsSection(
                    tournamentId: tournamentId,
                    playerCount: playerCount,
                    uid: uid,
                  ),

                  // ── VER BRACKET (torneos en curso o finalizados) ─────────
                  if (status == 'en_curso' || status == 'terminado') ...[
                    const SizedBox(height: 24),
                    _BracketCard(
                      tournamentId:   tournamentId,
                      tournamentName: name,
                      playerCount:    playerCount,
                      clubId:         clubId,
                      status:         status,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom bar con botón INSCRIBIRME ──────────────────────────────
      bottomNavigationBar: _BottomBar(
        tournamentId:        tournamentId,
        uid:                 uid,
        status:              status,
        tournamentName:      name,
        playerCount:         playerCount,
        tournamentCategory:  category,
        cost:                cost,
        clubId:              clubId,
        inscriptionDeadline: deadlineDate,
      ),
    );
  }

  Widget _infoCard(
      IconData icon, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ]),
      );

  Widget _deadlineCard(DateTime deadline) {
    final isPast = DateTime.now().isAfter(deadline);
    final color = isPast ? Colors.redAccent : Colors.orangeAccent;
    final label = isPast ? 'INSCRIPCIÓN CERRADA' : 'CIERRE DE INSCRIPCIÓN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(isPast ? Icons.lock_outline : Icons.event,
            color: color, size: 18),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              color: color, fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(DateFormat('dd/MM/yyyy').format(deadline),
              style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _statusChip(String status) {
    final n = normalizeTournamentStatus(status);
    Color color;
    String label;
    switch (n) {
      case 'proximamente':
        color = Colors.blueAccent;
        label = 'PRÓXIMAMENTE';
        break;
      case 'en_curso':
        color = Colors.greenAccent;
        label = 'EN CURSO';
        break;
      case 'terminado':
        color = Colors.white38;
        label = 'FINALIZADO';
        break;
      default: // 'open'
        color = Colors.orangeAccent;
        label = 'ABIERTO';
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER GRADIENT — fondo cuando no hay imagen de promo
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderGradient extends StatelessWidget {
  final String status;
  const _HeaderGradient({required this.status});

  @override
  Widget build(BuildContext context) {
    final n = normalizeTournamentStatus(status);
    final color = n == 'en_curso'
        ? Colors.greenAccent
        : n == 'terminado'
            ? Colors.white38
            : n == 'proximamente'
                ? Colors.blueAccent
                : Colors.orangeAccent;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.25),
            const Color(0xFF0A1F1A),
          ],
        ),
      ),
      child: Center(
          child: Icon(Icons.emoji_events,
              color: color.withOpacity(0.25), size: 90)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRACKET CARD — botón para ver el bracket cuando el torneo está activo/done
// ─────────────────────────────────────────────────────────────────────────────
class _BracketCard extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final int    playerCount;
  final String clubId;
  final String status;

  const _BracketCard({
    required this.tournamentId,
    required this.tournamentName,
    required this.playerCount,
    required this.clubId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final n        = normalizeTournamentStatus(status);
    final isDone   = n == 'terminado';
    final color    = isDone ? Colors.white38 : Colors.greenAccent;
    final icon     = isDone ? Icons.emoji_events : Icons.account_tree_outlined;
    final label    = isDone ? 'VER RESULTADOS FINALES' : 'VER BRACKET EN VIVO';
    final sublabel = isDone ? 'Torneo finalizado · mirá los resultados' : 'Torneo en curso · seguí los cruces';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TournamentPizarraViewScreen(
          clubId:         clubId,
          tournamentId:   tournamentId,
          tournamentName: tournamentName,
          playerCount:    playerCount,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          )),
          Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSCRIPTIONS SECTION — barra de cupos + lista de inscriptos
// ─────────────────────────────────────────────────────────────────────────────
class _InscriptionsSection extends StatelessWidget {
  final String tournamentId;
  final int playerCount;
  final String uid;

  const _InscriptionsSection({
    required this.tournamentId,
    required this.playerCount,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('inscriptions')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFCCFF00), strokeWidth: 2));
        }

        final docs      = snap.data!.docs;
        final count     = docs.length;
        final remaining = (playerCount - count).clamp(0, playerCount);
        final inscribed = docs.any((d) => d.id == uid);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Barra de cupos
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Text('CUPOS DISPONIBLES',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const Spacer(),
                Text('$remaining / $playerCount',
                    style: const TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: playerCount > 0 ? count / playerCount : 0,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(
                    remaining == 0
                        ? Colors.redAccent
                        : remaining <= (playerCount / 4).ceil()
                            ? Colors.orangeAccent
                            : const Color(0xFFCCFF00),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remaining == 0
                    ? 'Torneo completo'
                    : '$count inscriptos · $remaining lugares disponibles',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ]),
          ),

          // Badge "ya inscripto"
          if (inscribed) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 18),
                SizedBox(width: 10),
                Text('Ya estás inscripto en este torneo',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ],

          // Lista de inscriptos
          if (count > 0) ...[
            const SizedBox(height: 22),
            const Text('INSCRIPTOS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final d     = doc.data() as Map<String, dynamic>;
              final photo = d['photoUrl']?.toString() ?? '';
              final dName =
                  d['displayName']?.toString() ?? 'Jugador';
              final level =
                  d['tennisLevel']?.toString() ?? '';
              final isMe  = doc.id == uid;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFFCCFF00).withOpacity(0.05)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe
                        ? const Color(0xFFCCFF00).withOpacity(0.15)
                        : Colors.transparent,
                  ),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A3A34),
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? const Icon(Icons.person,
                            size: 18,
                            color: Colors.white38)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(dName,
                          style: TextStyle(
                              color: isMe
                                  ? const Color(0xFFCCFF00)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isMe
                                  ? FontWeight.bold
                                  : FontWeight.normal))),
                  if (level.isNotEmpty)
                    Text(level,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('VOS',
                          style: TextStyle(
                              color: Color(0xFFCCFF00),
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              );
            }),
          ],
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM BAR — botón INSCRIBIRME
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatefulWidget {
  final String    tournamentId;
  final String    uid;
  final String    status;
  final String    tournamentName;
  final int       playerCount;
  final String    tournamentCategory;
  final double    cost;
  final String    clubId;
  final DateTime? inscriptionDeadline;

  const _BottomBar({
    required this.tournamentId,
    required this.uid,
    required this.status,
    required this.tournamentName,
    required this.playerCount,
    required this.tournamentCategory,
    required this.cost,
    required this.clubId,
    this.inscriptionDeadline,
  });

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _loading = false;

  void _openPizarra(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => TournamentPizarraViewScreen(
        clubId:         widget.clubId,
        tournamentId:   widget.tournamentId,
        tournamentName: widget.tournamentName,
        playerCount:    widget.playerCount,
      ),
    ));
  }

  Future<void> _inscribir() async {
    if (_loading) return;
    if (_deadlinePassed) {
      _snack('El plazo de inscripción venció.', Colors.redAccent);
      return;
    }
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db   = FirebaseFirestore.instance;

      final userRef = db.collection('users').doc(widget.uid);
      final inscRef = db
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('inscriptions')
          .doc(widget.uid);

      // Leer datos del jugador (fuera de la transacción para obtener
      // displayName/photo que no cambian durante la inscripción)
      final userDoc  = await userRef.get();
      final userData = userDoc.data() ?? {};

      await db.runTransaction((tx) async {
        // Verificar cupos leyendo el conteo dentro de la transacción
        // no es posible con subcollection en una tx simple, así que
        // leemos antes y verificamos de nuevo al momento del set.
        final inscSnap = await db
            .collection('tournaments')
            .doc(widget.tournamentId)
            .collection('inscriptions')
            .get();

        if (inscSnap.docs.length >= widget.playerCount) {
          throw Exception('NO_SPOTS');
        }

        // Verificar si ya está inscripto
        final existingInsc = await tx.get(inscRef);
        if (existingInsc.exists) {
          throw Exception('ALREADY_INSCRIBED');
        }

        // Validar categoría (solo si el torneo tiene categoría estándar)
        const standardCategories = [
          '1era', '2nda', '3era', '4ta', '5ta', '6ta'
        ];
        if (standardCategories.contains(widget.tournamentCategory)) {
          final playerCategory =
              userData['category']?.toString() ?? '';
          if (playerCategory != widget.tournamentCategory) {
            throw Exception(
                'CATEGORY_MISMATCH|${widget.tournamentCategory}|$playerCategory');
          }
        }

        // Validar saldo de coins
        final coins =
            ((userData['balance_coins'] ?? 0) as num).toInt();
        if (widget.cost > 0 && coins < widget.cost) {
          throw Exception(
              'COINS_INSUFFICIENT|$coins|${widget.cost.toInt()}');
        }

        // Crear inscripción — usar foto de perfil de la app (no la de Google)
        tx.set(inscRef, {
          'uid':         widget.uid,
          'displayName': userData['displayName']
              ?? user.displayName ?? '',
          'photoUrl':    userData['photoUrl'] ?? '',
          'tennisLevel': userData['tennisLevel'] ?? '',
          'category':    userData['category']    ?? '',
          'email':       user.email              ?? '',
          'timestamp':   FieldValue.serverTimestamp(),
        });

        // Descontar coins si corresponde
        if (widget.cost > 0) {
          tx.update(userRef, {
            'balance_coins':
                FieldValue.increment(-widget.cost.toInt()),
          });
        }
      });

      // Registrar transacción de coins si hubo costo
      if (widget.cost > 0) {
        await FirebaseFirestore.instance
            .collection('users').doc(widget.uid)
            .collection('coin_transactions').add({
          'amount':      -widget.cost.toInt(),
          'type':        'tournament_inscription',
          'description': 'Inscripción en torneo "${widget.tournamentName}"',
          'createdAt':   FieldValue.serverTimestamp(),
          'date':        DateTime.now().toIso8601String(),
        });
      }

      // Notificación push de confirmación
      PushNotificationService.sendToUser(
        toUid: widget.uid,
        title: '¡Inscripción confirmada!',
        body: 'Te inscribiste en "${widget.tournamentName}". ¡Buena suerte!',
        type:  'tournament_inscription',
        extra: {'tournamentId': widget.tournamentId},
      );

      _snack('¡Te inscribiste en ${widget.tournamentName}!',
          const Color(0xFF1A4D32));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('NO_SPOTS')) {
        _snack('No hay lugares disponibles en este torneo.',
            Colors.redAccent);
      } else if (msg.contains('ALREADY_INSCRIBED')) {
        _snack('Ya estás inscripto en este torneo.', null);
      } else if (msg.contains('CATEGORY_MISMATCH')) {
        final parts = msg.split('|');
        final needed = parts.length > 1 ? parts[1] : '';
        final yours  = parts.length > 2 ? parts[2] : '';
        _snack(
          yours.isEmpty
              ? 'Tu categoría no coincide con la del torneo ($needed).'
              : 'Este torneo es para $needed. Tu categoría es $yours.',
          Colors.redAccent,
        );
      } else if (msg.contains('COINS_INSUFFICIENT')) {
        final parts = msg.split('|');
        final have = parts.length > 1 ? parts[1] : '?';
        final need = parts.length > 2 ? parts[2] : '?';
        _snack('Coins insuficientes. Tenés $have, se necesitan $need.',
            Colors.orangeAccent);
      } else {
        _snack('Error al inscribirse. Intentá de nuevo.',
            Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _deadlinePassed {
    final d = widget.inscriptionDeadline;
    if (d == null) return false;
    return DateTime.now().isAfter(d);
  }

  Future<void> _cancelar() async {
    // Bloquear desinscripción si se superó la fecha límite
    if (_deadlinePassed) {
      _snack('El plazo de inscripción venció. Ya no podés cancelar.',
          Colors.redAccent);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F1A),
        title: const Text('Cancelar inscripción',
            style: TextStyle(color: Colors.white)),
        content: Text(
          widget.cost > 0
              ? '¿Seguro que querés cancelar?\nSe te devolverán '
                '${widget.cost.toInt()} coins.'
              : '¿Seguro que querés cancelar tu inscripción?',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCELAR INSCRIPCIÓN',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final db      = FirebaseFirestore.instance;
      final inscRef = db
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('inscriptions')
          .doc(widget.uid);
      await inscRef.delete();
      if (widget.cost > 0) {
        await db.collection('users').doc(widget.uid).update({
          'balance_coins':
              FieldValue.increment(widget.cost.toInt()),
        });
        await db.collection('users').doc(widget.uid)
            .collection('coin_transactions').add({
          'amount':      widget.cost.toInt(),
          'type':        'tournament_refund',
          'description': 'Devolución por cancelar inscripción en "${widget.tournamentName}"',
          'createdAt':   FieldValue.serverTimestamp(),
          'date':        DateTime.now().toIso8601String(),
        });
      }
      _snack('Inscripción cancelada.', null);
    } catch (e) {
      _snack('Error al cancelar. Intentá de nuevo.',
          Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color? bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final n = normalizeTournamentStatus(widget.status);

    if (n == 'terminado') {
      return Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF060F0C),
          border: Border(top: BorderSide(
              color: Colors.white.withOpacity(0.07))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.emoji_events, size: 18),
            label: const Text('VER RESULTADOS',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1)),
            onPressed: () => _openPizarra(context),
          ),
        ),
      );
    }

    // Torneo próximamente → solo informativo
    if (n == 'proximamente') {
      return Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF060F0C),
          border: Border(top: BorderSide(
              color: Colors.white.withOpacity(0.07))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.15),
              foregroundColor: Colors.blueAccent,
              elevation: 0,
              side: const BorderSide(color: Colors.blueAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('INSCRIPCIONES PRÓXIMAMENTE',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5)),
            onPressed: null,
          ),
        ),
      );
    }


    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (ctx, userSnap) {
        final userData =
            userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final userCategory =
            userData['category']?.toString() ?? '';

        const std = ['1era', '2nda', '3era', '4ta', '5ta', '6ta'];
        final canInscribe =
            !std.contains(widget.tournamentCategory) ||
            userCategory.isEmpty ||
            userCategory == widget.tournamentCategory;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('inscriptions')
              .doc(widget.uid)
              .snapshots(),
          builder: (ctx, snap) {
            final inscribed = snap.data?.exists ?? false;

            return Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20,
                  12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: const Color(0xFF060F0C),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.07))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: _buildButton(inscribed, canInscribe),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildButton(bool inscribed, bool canInscribe) {
    final n = normalizeTournamentStatus(widget.status);

    // Categoría incorrecta → botón informativo bloqueado
    if (!canInscribe && n == 'open') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.04),
          foregroundColor: Colors.white24,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.lock_outline, size: 16),
        label: Text(
          'SOLO PARA CATEGORÍA ${widget.tournamentCategory.toUpperCase()}',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5),
        ),
        onPressed: null,
      );
    }

    // Inscripto en torneo abierto → mostrar botón cancelar (respetando deadline)
    if (inscribed && n == 'open') {
      final blocked = _deadlinePassed;
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: blocked ? Colors.white24 : Colors.redAccent,
          side: BorderSide(
              color: blocked ? Colors.white12 : Colors.redAccent),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.redAccent))
            : Icon(
                blocked ? Icons.lock_outline : Icons.cancel_outlined,
                size: 18),
        label: Text(
          blocked ? 'INSCRIPCIÓN CERRADA' : 'CANCELAR INSCRIPCIÓN',
          style: const TextStyle(
              fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        onPressed: (_loading || blocked) ? null : _cancelar,
      );
    }

    // Torneo en curso → mostrar bracket
    if (n == 'en_curso') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCCFF00),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.account_tree_outlined, size: 18),
        label: const Text('VER BRACKET',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1)),
        onPressed: () => _openPizarra(context),
      );
    }

    // Torneo abierto pero deadline pasado → mostrar bloqueado si no inscripto
    if (n == 'open' && _deadlinePassed && !inscribed) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.04),
          foregroundColor: Colors.white24,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: null,
        child: const Text('INSCRIPCIÓN CERRADA',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFCCFF00),
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _loading ? null : _inscribir,
      child: _loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.black))
          : const Text('INSCRIBIRME',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
    );
  }
}
