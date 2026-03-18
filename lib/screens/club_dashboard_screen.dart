import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import 'court_management_screen.dart';
import 'global_statistics_screen.dart';
import 'tournament_list_screen.dart';
import 'profile_screen.dart';

class ClubDashboardScreen extends StatelessWidget {
  final String clubId;

  const ClubDashboardScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CENTRO DE MANDOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
              builder: (context, snapshot) {
                String clubName = "Cargando...";
                if (snapshot.hasData && snapshot.data!.exists) {
                  clubName = (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? "Sede Desconocida";
                }
                return Text(clubName.toUpperCase(), style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5));
              }
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón de Agenda Global
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/global_statistics', arguments: clubId),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFFCCFF00), size: 32),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AGENDA GLOBAL', style: TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                          Text('Ver ocupación, recaudación y ocaso', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Color(0xFFCCFF00), size: 18),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Grid Unificado
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _buildGridItem(
                  context,
                  title: 'TORNEOS',
                  icon: Icons.emoji_events,
                  color: Colors.orangeAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentListScreen(clubId: clubId))),
                ),
                _buildGridItem(
                  context,
                  title: 'CANCHAS',
                  icon: Icons.sports_tennis,
                  color: const Color(0xFFCCFF00),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourtManagementScreen())),
                ),
                _buildGridItem(
                  context,
                  title: 'CLUBES',
                  subtitle: "Sede activa: El Pinar",
                  icon: Icons.stadium,
                  color: Colors.lightBlueAccent,
                  onTap: () => Navigator.pushNamed(context, '/club_explorer'),
                ),
                _buildGridItem(
                  context,
                  title: 'JUGADORES',
                  icon: Icons.groups,
                  color: Colors.white70,
                  onTap: () => Navigator.pushNamed(context, '/tournament_players', arguments: clubId),
                ),
              ],
            ),

            const SizedBox(height: 30),
            
            const Text(
              'NOVEDADES',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 15),
            _buildNewsModule(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, {required String title, String? subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C4A44).withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 8), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsModule() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20)),
            child: const Center(child: Text('Sin novedades recientes', style: TextStyle(color: Colors.white24, fontSize: 12))),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(_getNewsIcon(data['type']), color: const Color(0xFFCCFF00), size: 18),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      data['message'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white10, size: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getNewsIcon(String? type) {
    switch (type) {
      case 'player': return Icons.sports_tennis;
      case 'tournament': return Icons.emoji_events;
      case 'match': return Icons.edit_note;
      default: return Icons.notifications;
    }
  }
}
