import 'package:flutter/material.dart';

class ClubSetupScreen extends StatelessWidget {
  const ClubSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Configurar mi Club', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Bienvenido, Administrador.\nAquí configurarás las canchas y horarios de tu club.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
