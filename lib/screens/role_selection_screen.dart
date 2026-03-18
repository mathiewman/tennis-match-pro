import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;
  String? _selectedRole;

  Future<void> _selectRole(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });

    try {
      await AuthService().updateUserRole(uid, role);
      // No hace falta navegar manualmente — el StreamBuilder del AuthGate
      // detecta el cambio de rol en Firestore y redirige automáticamente.
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedRole = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el rol: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Bienvenido a\nTennis Match Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Para empezar, dinos quién eres:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 48),
                  _buildRoleCard(
                    icon: Icons.sports_tennis,
                    title: 'Soy Jugador',
                    subtitle: 'Busca oponentes, juega partidos y sube en el ranking.',
                    role: 'player',
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    icon: Icons.school,
                    title: 'Soy Profesor',
                    subtitle: 'Gestiona tus clases, alumnos y carga resultados.',
                    role: 'coach',
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    icon: Icons.business,
                    title: 'Soy Coordinador',
                    subtitle: 'Administra la logística de los turnos y canchas.',
                    role: 'coordinator',
                  ),
                ],
              ),
            ),

            // Overlay de carga mientras se guarda el rol
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFCCFF00),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedRole == 'player'
                            ? 'Configurando tu perfil de jugador...'
                            : _selectedRole == 'coordinator'
                            ? 'Configurando tu perfil de coordinador...'
                            : 'Configurando tu perfil...',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String role,
  }) {
    final isSelected = _selectedRole == role && _isLoading;

    return InkWell(
      onTap: _isLoading ? null : () => _selectRole(role),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCCFF00).withOpacity(0.15)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFCCFF00) : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48,
                color: isSelected ? const Color(0xFFCCFF00) : const Color(0xFFCCFF00)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            isSelected
                ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00), strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}