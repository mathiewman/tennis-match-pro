import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'matchmaking_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _dbService = DatabaseService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  DateTime _selectedDate = DateTime.now();
  bool _isToday = true;
  String _selectedTimeSlot = "18:00 - 20:00";

  Map<String, dynamic> _getEloLevel(int elo) {
    if (elo < 1200) return {'level': 'Principiante', 'nextLevel': 'Amateur', 'progress': elo / 1200};
    if (elo < 1500) return {'level': 'Amateur', 'nextLevel': 'Semi-Pro', 'progress': (elo - 1200) / 300};
    if (elo < 1800) return {'level': 'Semi-Pro', 'nextLevel': 'Profesional', 'progress': (elo - 1500) / 300};
    return {'level': 'Profesional', 'nextLevel': 'Leyenda', 'progress': (elo - 1800) / 300};
  }

  Future<void> _updateAvailability(bool isAvailable, Player currentPlayer) async {
    if (_currentUser == null) return;
    
    final status = isAvailable ? 'disponible' : 'ocupado';
    final date = _isToday ? DateTime.now() : _selectedDate;

    await _dbService.savePlayer(Player(
      id: _currentUser!.uid,
      displayName: currentPlayer.displayName, 
      email: currentPlayer.email,
      photoUrl: currentPlayer.photoUrl,
      eloRating: currentPlayer.eloRating,
      tennisLevel: currentPlayer.tennisLevel,
      status: status,
      availableDate: Timestamp.fromDate(date),
      availableTimeSlot: _selectedTimeSlot,
      balance_coins: currentPlayer.balance_coins,
      role: currentPlayer.role,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const Scaffold(body: Center(child: Text('No hay sesión')));

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Mi Perfil Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _dbService.getPlayerStream(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
             return const Center(child: Text('Cargando perfil...', style: TextStyle(color: Colors.white)));
          }

          final player = Player.fromFirestore(snapshot.data!);
          final eloInfo = _getEloLevel(player.eloRating);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMainCard(player, eloInfo),
                const SizedBox(height: 20),
                _buildCoinsCard(player.balance_coins),
                const SizedBox(height: 20),
                _buildAvailabilityConfig(player),
                const SizedBox(height: 30),
                _buildActionButton(player.status == 'disponible'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard(Player player, Map<String, dynamic> eloInfo) {
    // Usamos photoURL directamente de Firebase Auth para mayor fiabilidad inicial,
    // o el del documento si ya está guardado.
    final String? photoUrl = _currentUser?.photoURL ?? player.photoUrl;

    return Card(
      color: const Color(0xFF2C4A44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 35, 
                  backgroundColor: Colors.white10,
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) 
                      ? NetworkImage(photoUrl) 
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person, size: 40, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.displayName, 
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        player.tennisLevel, 
                        style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ELO: ${player.eloRating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(eloInfo['level'], style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: eloInfo['progress'], 
              color: const Color(0xFFCCFF00), 
              backgroundColor: Colors.white10,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinsCard(int coins) {
    return Card(
      color: const Color(0xFF2C4A44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            const Icon(Icons.monetization_on, color: Color(0xFFCCFF00), size: 30),
            const SizedBox(width: 15),
            const Text('Mis Coins:', style: TextStyle(color: Colors.white, fontSize: 18)),
            const Spacer(),
            Text('$coins', style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityConfig(Player player) {
    bool isAvailable = player.status == 'disponible';

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Disponible para jugar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A3A34))),
                Switch(
                  value: isAvailable,
                  activeColor: const Color(0xFFCCFF00),
                  activeTrackColor: const Color(0xFF1A3A34).withOpacity(0.5),
                  onChanged: (val) => _updateAvailability(val, player),
                ),
              ],
            ),
            if (isAvailable) ...[
              const Divider(),
              CheckboxListTile(
                title: const Text('Hoy mismo'),
                value: _isToday,
                activeColor: const Color(0xFF1A3A34),
                onChanged: (val) => setState(() => _isToday = val ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (!_isToday)
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 14)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
              const SizedBox(height: 10),
              const Text('Rango Horario:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedTimeSlot,
                isExpanded: true,
                items: ["09:00 - 11:00", "11:00 - 13:00", "16:00 - 18:00", "18:00 - 20:00", "20:00 - 22:00"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedTimeSlot = val!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isAvailable) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCCFF00),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: isAvailable 
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchmakingScreen()))
          : null,
        child: Text(
          'BUSCAR OPONENTE', 
          style: TextStyle(
            color: isAvailable ? Colors.black : Colors.black38, 
            fontWeight: FontWeight.bold, 
            fontSize: 16
          )
        ),
      ),
    );
  }
}
