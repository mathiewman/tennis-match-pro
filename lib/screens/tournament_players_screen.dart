import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentPlayersScreen extends StatefulWidget {
  const TournamentPlayersScreen({super.key});

  @override
  State<TournamentPlayersScreen> createState() => _TournamentPlayersScreenState();
}

class _TournamentPlayersScreenState extends State<TournamentPlayersScreen> {
  String? _clubId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clubId = ModalRoute.of(context)!.settings.arguments as String?;
  }

  Future<void> _deletePlayer(String playerId, bool isManual) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44),
        title: const Text('¿Eliminar jugador?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirmed == true && _clubId != null) {
      if (isManual) {
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(_clubId)
            .collection('tournament_players')
            .doc(playerId)
            .delete();
      } else {
        // Para jugadores registrados (usuarios reales), quizás solo querés quitar el vínculo con el club
        // o marcarlo como inactivo en este club específico. 
        // Por ahora, si es la lista de "jugadores del club", lo borramos de la subcolección.
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(_clubId)
            .collection('club_players') 
            .doc(playerId)
            .delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clubId == null) return const Scaffold(body: Center(child: Text("Error: No Club ID")));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3A34),
        appBar: AppBar(
          title: const Text('Gestión de Jugadores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFFCCFF00),
            labelColor: Color(0xFFCCFF00),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'REGISTRADOS', icon: Icon(Icons.verified_user)),
              Tab(text: 'MANUALES', icon: Icon(Icons.person_add_alt)),
            ],
          ),
        ),
        body: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFCCFF00)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.white24), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                    : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlayerList(isManual: false),
                  _buildPlayerList(isManual: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList({required bool isManual}) {
    // Para simplificar, asumimos que los manuales están en 'tournament_players' 
    // y los registrados en 'club_players' (o similar según tu estructura)
    final collectionName = isManual ? 'tournament_players' : 'club_players';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(_clubId)
          .collection(collectionName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(isManual ? 'No hay jugadores manuales' : 'No hay jugadores registrados', style: const TextStyle(color: Colors.white24)));
        }

        var docs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final name = (d.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery);
          }).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;

            return Card(
              color: Colors.white.withOpacity(0.03),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isManual ? Colors.orangeAccent.withOpacity(0.2) : const Color(0xFFCCFF00).withOpacity(0.2),
                  child: Icon(isManual ? Icons.edit_note : Icons.verified, color: isManual ? Colors.orangeAccent : const Color(0xFFCCFF00), size: 20),
                ),
                title: Text(data['name'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(data['category'] ?? 'Sin categoría', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _deletePlayer(id, isManual),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
