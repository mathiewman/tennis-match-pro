import 'package:flutter/material.dart';
import 'tournament_manual_config_screen.dart';
import 'tournament_auto_config_screen.dart';

class TournamentTypeSelectionScreen extends StatelessWidget {
  final String clubId;

  const TournamentTypeSelectionScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Nuevo Torneo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTypeCard(
              context,
              title: 'Torneo Manual',
              subtitle: 'Digitalizá un torneo existente armando las llaves a mano.',
              icon: Icons.edit_document,
              color: Colors.amberAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TournamentManualConfigScreen(clubId: clubId)),
              ),
            ),
            const SizedBox(height: 20),
            _buildTypeCard(
              context,
              title: 'Torneo Automático',
              subtitle: 'La app organiza los cruces y pide disponibilidad a los jugadores.',
              icon: Icons.auto_awesome,
              color: const Color(0xFFCCFF00),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TournamentAutoConfigScreen(clubId: clubId)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 50),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
