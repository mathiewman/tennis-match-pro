import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'match_request_screen.dart';

typedef OpponentWithDistance = ({Player player, double distance});

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Player>>? _opponentsStream;
  Position? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  Future<void> _initializeSearch() async {
    if (_currentUserId == null) return;
    try {
      _currentUserPosition = await _locationService.getCurrentPosition();
      
      // Obtenemos el perfil para saber el nivel
      final playerDoc = await _dbService.getPlayerStream(_currentUserId!).first;
      if (!playerDoc.exists) return;
      
      final currentPlayer = Player.fromFirestore(playerDoc);
      
      setState(() {
        _opponentsStream = _dbService.getOpponentsStream(
          tennisLevel: currentPlayer.tennisLevel,
          currentUserId: _currentUserId!,
        );
      });
    } catch (e) {
      // Error silencioso para no trabar la UI según pedido
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Oponentes Disponibles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_opponentsStream == null || _currentUserPosition == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
    }

    return StreamBuilder<List<Player>>(
      stream: _opponentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
        }

        final List<Player> opponents = snapshot.data ?? [];
        
        final List<OpponentWithDistance> nearbyOpponents = opponents
            .map((opponent) {
              final distance = opponent.location != null
                  ? Geolocator.distanceBetween(
                      _currentUserPosition!.latitude,
                      _currentUserPosition!.longitude,
                      opponent.location!.latitude,
                      opponent.location!.longitude,
                    ) / 1000
                  : 1.0; // Distancia ficticia por defecto para mocks
              return (player: opponent, distance: distance);
            })
            .toList();

        nearbyOpponents.sort((a, b) => a.distance.compareTo(b.distance));

        if (nearbyOpponents.isEmpty) {
          return _buildNoOpponentsFound();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: nearbyOpponents.length,
          itemBuilder: (context, index) {
            final opData = nearbyOpponents[index];
            return _buildOpponentCard(opData.player, opData.distance);
          },
        );
      },
    );
  }

  Widget _buildOpponentCard(Player opponent, double distance) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              backgroundImage: (opponent.photoUrl != null && opponent.photoUrl!.isNotEmpty) 
                  ? NetworkImage(opponent.photoUrl!) 
                  : null,
              child: (opponent.photoUrl == null || opponent.photoUrl!.isEmpty) 
                  ? const Icon(Icons.person, size: 30, color: Colors.grey) 
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opponent.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A3A34))),
                  const SizedBox(height: 2),
                  Text('${opponent.tennisLevel} • ${opponent.preferredHand}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('A ${distance.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MatchRequestScreen(
                    opponent: opponent,
                    currentUserPosition: _currentUserPosition!,
                  ),
                ));
              },
              child: const Text('PROPONER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOpponentsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white54, size: 80),
          const SizedBox(height: 20),
          const Text('No hay oponentes disponibles.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _initializeSearch,
            child: const Text('REINTENTAR BÚSQUEDA'),
          )
        ],
      ),
    );
  }
}
