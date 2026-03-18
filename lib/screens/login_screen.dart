import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34), // Wimbledon Green
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tennis Match Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 60),
              _isSigningIn
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.sports_tennis, color: Color(0xFF1A3A34)),
                      label: const Text(
                        'Iniciar sesión con Google',
                        style: TextStyle(fontSize: 18, color: Color(0xFF1A3A34), fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00), // Tennis Ball Yellow
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _signIn,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
    });

    final authService = AuthService();

    try {
      // El AuthService ya se encarga de _ensureUserInFirestore
      // No necesitamos duplicar lógica aquí ni llamar a playerExists
      final userCredential = await authService.signInWithGoogle();

      if (mounted && userCredential != null) {
        // Exito. El AuthGate en main.dart detectará el cambio y redirigirá.
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al iniciar sesión. Inténtalo de nuevo.')),
          );
        }
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ocurrió un error: $e')),
          );
        }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }
}
