import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/club_dashboard_screen.dart';
import '../screens/register_club_screen.dart';
import '../screens/home_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../services/database_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

            // Doc aún no creado (raro pero posible en el primer login)
            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const _LoadingScreen();
            }

            final userData = userSnap.data!.data() ?? {};
            final String role = userData['role'] ?? 'pending';

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
                return HomeScreen(userData: userData);

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
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseService().getClubByOwner(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final clubData = snap.data;

        // Ya tiene club → ir directo al dashboard
        if (clubData != null) {
          final clubId = clubData['id']?.toString() ?? '';
          if (clubId.isNotEmpty) {
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
