import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';
import 'register_club_screen.dart';
import 'club_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final String role = userData['role'] ?? 'player';

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: Text(
          _getAppBarTitle(role),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _buildBodyForRole(context, role, user),
      floatingActionButton: _buildFloatingActionButton(context, role),
    );
  }

  String _getAppBarTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Home (Admin)';
      case 'coordinator':
        return 'Home (Coordinador)';
      default:
        return 'Tennis Match Pro';
    }
  }

  Widget _buildBodyForRole(BuildContext context, String role, User user) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (role == 'admin')
                const Text("Vista de Administrador", style: TextStyle(color: Colors.amber, fontSize: 16))
              else if (role == 'coordinator')
                const Text("Vista de Coordinador", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16)),
              
              const SizedBox(height: 10),
    
              const Text('¡Bienvenido!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white10,
                      backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty) 
                          ? NetworkImage(user.photoURL!) 
                          : null,
                      child: (user.photoURL == null || user.photoURL!.isEmpty)
                          ? const Icon(Icons.person, size: 60, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(user.displayName ?? 'Jugador', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Toca para ver tu perfil', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
              
              if (role == 'coordinator') ...[
                const SizedBox(height: 40),
                FutureBuilder<Map<String, dynamic>?>(
                  future: DatabaseService().getClubByOwner(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    
                    final clubData = snapshot.data;
                    
                    if (clubData == null) {
                      return ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterClubScreen())),
                        icon: const Icon(Icons.add_business),
                        label: const Text('Registrar Mi Club'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                      );
                    } else {
                      return ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDashboardScreen(clubId: clubData['id']))),
                        icon: const Icon(Icons.dashboard),
                        label: const Text('Ir a Mi Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, String role) {
    if (role == 'admin') {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
        },
        backgroundColor: const Color(0xFFCCFF00),
        child: const Icon(Icons.admin_panel_settings, color: Color(0xFF1A3A34)),
        tooltip: 'Panel de Admin',
      );
    }
    return null;
  }
}
