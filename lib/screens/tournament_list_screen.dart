import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tournament_manual_config_screen.dart';
import 'tournament_management_screen.dart'; // <--- CAMBIADO DE 'tournament_pizarra_screen.dart'

class TournamentListScreen extends StatelessWidget {
  final String clubId;

  const TournamentListScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Cartelera de Torneos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments').where('clubId', isEqualTo: clubId).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
          
          final tournaments = snapshot.data!.docs;
          debugPrint("DEBUG: Torneos en Firestore = ${tournaments.length}");

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: tournaments.length + 2, // Aumentado en 2: uno para el botón y otro para el espacio extra
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentManualConfigScreen(clubId: clubId))),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text('NUEVO TORNEO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  );
                } else if (index == tournaments.length + 1) {
                  // Espacio extra después del último torneo
                  return const SizedBox(height: 80);
                }

                final tournamentDoc = tournaments[index - 1];
                final data = tournamentDoc.data() as Map<String, dynamic>;
                return _buildTournamentCard(context, tournamentDoc.id, data, currentUser?.uid);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, String id, Map<String, dynamic> data, String? currentUid) {
    final String name = (data['name'] ?? 'TORNEO').toString().toUpperCase();
    final String category = data['category'] ?? '---';
    final String? promoUrl = data['promoUrl'];
    final int totalSpots = data['playerCount'] ?? 16;
    final String? creatorId = data['creatorId'];
    final String? targetClubId = data['clubId'];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentManagementScreen(clubId: clubId, tournamentId: id, tournamentName: name, playerCount: totalSpots))), // <--- CAMBIADO A TournamentManagementScreen
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF2C4A44),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            children: [
              Positioned.fill(
                child: promoUrl != null && promoUrl.isNotEmpty
                    ? Image.network(
                        promoUrl, 
                        fit: BoxFit.cover, 
                        errorBuilder: (c, e, s) => _buildPlaceholder(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      )
                    : _buildPlaceholder(),
              ),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)])))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFCCFF00), borderRadius: BorderRadius.circular(10)), child: Text(category, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
                        if (currentUid != null && currentUid == creatorId)
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            onPressed: () => _confirmDelete(context, id),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Cambio: Mostrar nombre del club dinámicamente
                        if (targetClubId != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('clubs').doc(targetClubId).get(),
                            builder: (context, clubSnap) {
                              String clubName = "CARGANDO CLUB...";
                              if (clubSnap.hasData && clubSnap.data!.exists) {
                                clubName = (clubSnap.data!.get('name') ?? 'CLUB DESCONOCIDO').toString().toUpperCase();
                              }
                              return Expanded(
                                child: Text(
                                  clubName, 
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          )
                        else
                          const Text('CLUB SEDE CENTRAL', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('tournaments').doc(id).collection('temp_layout').doc('current').snapshots(),
                          builder: (context, snapshot) {
                            int registered = 0;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final slots = snapshot.data!.get('slots') as Map<String, dynamic>;
                              registered = slots.keys.where((k) => int.parse(k) < totalSpots).length;
                            }
                            int free = totalSpots - registered;
                            return Text(
                              'LIBRES: $free / $totalSpots',
                              style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 10, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('Eliminar Torneo', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar este torneo? Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('tournaments').doc(id).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(color: const Color(0xFF2C4A44), child: const Center(child: Icon(Icons.emoji_events_outlined, color: Colors.white10, size: 50)));
  }
}