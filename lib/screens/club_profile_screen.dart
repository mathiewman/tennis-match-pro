import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../models/court_model.dart';
import 'tournament_pizarra_view_screen.dart';

class ClubProfileScreen extends StatefulWidget {
  final String clubId;

  const ClubProfileScreen({super.key, required this.clubId});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen> {
  final DatabaseService _db = DatabaseService();
  final LocationService _locationService = LocationService();
  Position? _userPosition;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  Future<void> _launchWhatsApp(String phone, String clubName) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('54')) cleanPhone = '549$cleanPhone';
    final message = "Hola, te contacto desde la app Tennis Match Pro por el club $clubName...";
    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
          if (!snapshot.data!.exists) return const Center(child: Text("Club no encontrado", style: TextStyle(color: Colors.white)));
          
          final club = snapshot.data!.data() as Map<String, dynamic>;
          final GeoPoint clubLoc = club['location'] ?? const GeoPoint(-33.33, -60.21);
          final String ownerId = club['ownerId'] ?? '';
          final bool isOwner = _currentUserId == ownerId;
          final String? photoUrl = club['photoUrl'] ?? club['imageUrl'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFF1A3A34),
                iconTheme: const IconThemeData(color: Colors.white),
                title: !isOwner ? _buildSpectatorBadge() : null,
                actions: [
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFFCCFF00)),
                      onPressed: () => Navigator.pushNamed(context, '/edit_club', arguments: widget.clubId),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: (photoUrl != null && photoUrl.isNotEmpty)
                    ? Image.network(photoUrl, fit: BoxFit.cover)
                    : _buildImagePlaceholder(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((club['name'] ?? '').toString().toUpperCase(), 
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFCCFF00), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(club['address'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14))),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // NUEVA SECCIÓN: TORNEOS PARA ESPECTADORES
                      const Text("TORNEOS Y RESULTADOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      _buildTournamentSection(widget.clubId),

                      const SizedBox(height: 30),
                      
                      // Info del Coordinador (Siempre visible)
                      _buildCoordinatorInfo(ownerId, club),

                      const SizedBox(height: 30),
                      
                      const Text("UBICACIÓN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      _buildMapCard(clubLoc),
                      
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildSpectatorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, color: Colors.blueAccent, size: 14),
          SizedBox(width: 8),
          Text("MODO ESPECTADOR", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTournamentSection(String clubId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tournaments').where('clubId', isEqualTo: clubId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final tournaments = snapshot.data!.docs;
        if (tournaments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(15)),
            child: const Center(child: Text("No hay torneos activos en este momento", style: TextStyle(color: Colors.white24, fontSize: 12))),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tournaments.length,
          itemBuilder: (context, index) {
            final t = tournaments[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Color(0xFFCCFF00)),
                title: Text(t['name']?.toString().toUpperCase() ?? 'Torneo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("${t['category'] ?? ''} - ${t['playerCount'] ?? 0} Jugadores", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCCFF00).withOpacity(0.1), elevation: 0),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentPizarraViewScreen(
                      clubId: widget.clubId, // <--- Se agregó este parámetro
                      tournamentId: tournaments[index].id,
                      tournamentName: t['name'],
                      playerCount: t['playerCount'] ?? 16,
                    )));
                  },
                  child: const Text("VER PIZARRA", style: TextStyle(color: Color(0xFFCCFF00), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoordinatorInfo(String ownerId, Map<String, dynamic> club) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(ownerId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();
        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("COORDINADOR", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(userData['displayName'] ?? 'No disponible', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (club['phone'] != null) ...[
                const Divider(color: Colors.white10, height: 24),
                InkWell(
                  onTap: () => _launchWhatsApp(club['phone'], club['name']),
                  child: Row(
                    children: [
                      const Icon(Icons.chat, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(club['phone'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                        const Text("WhatsApp de contacto", style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapCard(GeoPoint loc) {
    return Container(
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(loc.latitude, loc.longitude), zoom: 15),
          markers: {Marker(markerId: const MarkerId('club'), position: LatLng(loc.latitude, loc.longitude))},
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.stadium, size: 100, color: Colors.white10)));
  }
}
