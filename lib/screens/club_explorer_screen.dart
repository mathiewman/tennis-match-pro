import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'club_profile_screen.dart';
import 'club_dashboard_screen.dart';

class ClubExplorerScreen extends StatefulWidget {
  const ClubExplorerScreen({super.key});

  @override
  State<ClubExplorerScreen> createState() => _ClubExplorerScreenState();
}

class _ClubExplorerScreenState extends State<ClubExplorerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('EXPLORAR CLUBES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar club por nombre...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFCCFF00)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white24),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ''; });
                      },
                    )
                  : null,
              ),
              onChanged: (value) {
                setState(() { _searchQuery = value.toLowerCase(); });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay clubes registrados', style: TextStyle(color: Colors.white24)));
                }

                List<DocumentSnapshot> clubs = snapshot.data!.docs;

                // Filtrar por búsqueda
                if (_searchQuery.isNotEmpty) {
                  clubs = clubs.where((doc) {
                    final name = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery);
                  }).toList();
                }

                // Ordenar: Mi club primero
                clubs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final isOwnerA = dataA['ownerId'] == currentUser?.uid;
                  final isOwnerB = dataB['ownerId'] == currentUser?.uid;
                  if (isOwnerA && !isOwnerB) return -1;
                  if (!isOwnerA && isOwnerB) return 1;
                  return 0;
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index].data() as Map<String, dynamic>;
                    final clubId = clubs[index].id;
                    final isMyClub = club['ownerId'] == currentUser?.uid;
                    final String? photoUrl = club['photoUrl'] ?? club['imageUrl'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () {
                          if (isMyClub) {
                            // SI es mi club: Navegar a Gestión Completa
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDashboardScreen(clubId: clubId)));
                          } else {
                            // SI es otro club: Navegar a Perfil en modo Espectador
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId)));
                          }
                        },
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isMyClub ? const Color(0xFFCCFF00).withOpacity(0.5) : Colors.white10,
                              width: isMyClub ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Stack(
                              children: [
                                // Foto de fondo
                                if (photoUrl != null && photoUrl.isNotEmpty)
                                  Positioned.fill(
                                    child: Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      color: Colors.black.withOpacity(0.6),
                                      colorBlendMode: BlendMode.darken,
                                    ),
                                  )
                                else
                                  Positioned.fill(
                                    child: Container(
                                      color: const Color(0xFF2C4A44).withOpacity(0.5),
                                      child: const Icon(Icons.business, color: Colors.white10, size: 50),
                                    ),
                                  ),
                                
                                // Contenido
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    club['name']?.toString().toUpperCase() ?? 'CLUB SIN NOMBRE',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMyClub)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 10),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFCCFF00),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Text('MI SEDE (ADMIN)', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, color: Color(0xFFCCFF00), size: 14),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    club['address'] ?? 'Ubicación no disponible',
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white38),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
