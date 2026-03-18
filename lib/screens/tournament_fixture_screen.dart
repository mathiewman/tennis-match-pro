
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/tournament_model.dart';
import '../services/database_service.dart';

class TournamentFixtureScreen extends StatefulWidget {
  final String clubId;
  const TournamentFixtureScreen({super.key, required this.clubId});

  @override
  State<TournamentFixtureScreen> createState() => _TournamentFixtureScreenState();
}

class _TournamentFixtureScreenState extends State<TournamentFixtureScreen> {
  final DatabaseService _dbService = DatabaseService();
  final List<String> _rounds = ['Octavos', 'Cuartos', 'Semis', 'Final'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Fixture del Torneo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rounds.length,
        itemBuilder: (context, index) {
          final round = _rounds[index];
          return _buildRoundSection(round);
        },
      ),
    );
  }

  Widget _buildRoundSection(String round) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            round.toUpperCase(),
            style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .doc('manual_torneo_${widget.clubId}')
              .collection('matches')
              .where('round', isEqualTo: round)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final matches = snapshot.data!.docs;

            if (matches.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 20),
                child: Text('Sin partidos definidos en esta ronda.', style: TextStyle(color: Colors.white24, fontSize: 12)),
              );
            }

            return Column(
              children: matches.map((doc) {
                final match = TournamentMatch.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                return _buildMatchCard(match);
              }).toList(),
            );
          },
        ),
        const Divider(color: Colors.white10, height: 40),
      ],
    );
  }

  Widget _buildMatchCard(TournamentMatch match) {
    bool isPlayed = match.status == 'played';

    return Card(
      color: const Color(0xFF2C4A44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildPlayerRow(match.player1Id, match.winnerId == match.player1Id)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('VS', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: _buildPlayerRow(match.player2Id, match.winnerId == match.player2Id)),
              ],
            ),
            if (isPlayed) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'SCORE: ${match.score.join(" / ")}',
                  style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ] else ...[
              const SizedBox(height: 15),
              TextButton.icon(
                onPressed: () {
                  // Reusar el modal de anotación si es necesario o navegar a carga
                },
                icon: const Icon(Icons.edit_note, color: Color(0xFFCCFF00)),
                label: const Text('ANOTAR RESULTADO', style: TextStyle(color: Color(0xFFCCFF00), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(String playerId, bool isWinner) {
    if (playerId.isEmpty) {
      return const Text('Esperando Ganador', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, fontSize: 13));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(playerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('...', style: TextStyle(color: Colors.white24));
        final name = snapshot.data!.get('displayName') ?? 'Jugador';
        
        return Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isWinner ? const Color(0xFFCCFF00) : Colors.white,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
