import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/player_home_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/club_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH GATE
// Escucha el stream de autenticación de Firebase y decide qué pantalla mostrar.
//
// Flujo completo:
//   Sin sesión         → LoginScreen
//   Rol 'pending'      → RoleSelectionScreen
//   Jugador nuevo      → OnboardingScreen  (onboardingDone == false)
//   Jugador completo   → PlayerHomeScreen
//   Coordinador        → ClubDashboardScreen
//   Admin              → AdminDashboardScreen
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        // 1. Cargando estado de auth
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        // 2. Sin sesión → Login
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginScreen();
        }

        final uid = authSnap.data!.uid;

        // 3. Con sesión → escuchar el doc del usuario en Firestore
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }

            // Doc no existe todavía (puede pasar en el primer frame)
            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const _SplashLoader();
            }

            final data = userSnap.data!.data()!;
            final role           = data['role']           as String? ?? 'pending';
            final onboardingDone = data['onboardingDone'] as bool?   ?? false;

            // 4. Sin rol → elegir rol
            if (role == 'pending') {
              return const RoleSelectionScreen();
            }

            // 5. Jugador sin onboarding → onboarding
            if (role == 'player' && !onboardingDone) {
              return const OnboardingScreen();
            }

            // 6. Redirigir según rol
            switch (role) {
              case 'admin':
                return const AdminDashboardScreen();

              case 'coordinator':
                final clubId = data['clubId'] as String? ?? '';
                if (clubId.isEmpty) {
                  // Coordinador sin club → que lo registre
                  // (el ClubDashboardScreen maneja este caso internamente)
                  return ClubDashboardScreen(clubId: '');
                }
                return ClubDashboardScreen(clubId: clubId);

              case 'player':
              default:
                return PlayerHomeScreen(userData: data);
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH LOADER — pantalla de carga mientras se resuelve el estado
// ─────────────────────────────────────────────────────────────────────────────
class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1F1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFCCFF00)),
            SizedBox(height: 20),
            Text(
              'TENNIS MATCH PRO',
              style: TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
