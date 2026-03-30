import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/club_dashboard_screen.dart';
import '../screens/register_club_screen.dart';
import '../screens/home_screen.dart';
import '../screens/player_home_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../services/database_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Timeout de seguridad: si el doc de Firestore no aparece en 8 s,
  // hacemos sign-out para evitar carga infinita.
  Timer? _docTimeoutTimer;
  bool _docTimedOut = false;

  void _startDocTimeout() {
    _docTimeoutTimer?.cancel();
    _docTimedOut = false;
    _docTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _docTimedOut = true);
        FirebaseAuth.instance.signOut();
      }
    });
  }

  void _cancelDocTimeout() {
    _docTimeoutTimer?.cancel();
    _docTimeoutTimer = null;
  }

  @override
  void dispose() {
    _docTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // Sin sesión → Login
        if (!snapshot.hasData) {
          _cancelDocTimeout();
          return const LoginScreen();
        }

        final uid = snapshot.data!.uid;

        // Con sesión → escuchar perfil del usuario
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            // Doc aún no creado (posible en el primer login o si falló la escritura)
            if (!userSnap.hasData || !userSnap.data!.exists) {
              // Iniciar timeout para no quedar cargando infinitamente
              _startDocTimeout();
              return const _LoadingScreen();
            }

            // Doc encontrado → cancelar timeout
            _cancelDocTimeout();

            final userData = userSnap.data!.data() ?? {};
            final String role = userData['role'] ?? 'pending';
            final bool onboardingDone = userData['onboardingDone'] as bool? ?? false;

            switch (role) {

              // ── Coordinador ─────────────────────────────────────────────
              case 'coordinator':
                return _CoordinatorGate(uid: uid, userData: userData);

              // ── Admin ───────────────────────────────────────────────────
              case 'admin':
                return const AdminDashboardScreen();

              // ── Jugador / Coach ─────────────────────────────────────────
              case 'player':
              case 'coach':
                if (!onboardingDone) {
                  return const OnboardingScreen();
                }
                return PlayerHomeScreen(userData: userData);

              // ── Sin rol — elegir rol ────────────────────────────────────
              case 'pending':
              default:
                return const RoleSelectionScreen();
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COORDINADOR GATE — verifica si ya tiene club, si no lo manda a crearlo
// ─────────────────────────────────────────────────────────────────────────────
class _CoordinatorGate extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const _CoordinatorGate({required this.uid, required this.userData});

  @override
  Widget build(BuildContext context) {
    // Primero: si el doc del usuario ya tiene admin_club_id, usarlo directamente
    final directClubId = userData['admin_club_id']?.toString() ?? '';
    if (directClubId.isNotEmpty) {
      return ClubDashboardScreen(clubId: directClubId);
    }

    // Si no, buscar club donde el usuario es dueño (ownerId)
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseService().getClubByOwner(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final clubData = snap.data;

        if (clubData != null) {
          final clubId = clubData['id']?.toString() ?? '';
          if (clubId.isNotEmpty) {
            // Guardar admin_club_id para la próxima vez
            FirebaseFirestore.instance
                .collection('users').doc(uid)
                .update({'admin_club_id': clubId}).catchError((_) {});
            return ClubDashboardScreen(clubId: clubId);
          }
        }

        // No tiene club → crear uno
        return const RegisterClubScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE CARGA — mientras se resuelven las queries
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1F1A),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
