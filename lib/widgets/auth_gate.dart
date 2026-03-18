import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 1. Si no hay sesión iniciada, mostrar Login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final uid = snapshot.data!.uid;

        // 2. Escuchar datos del usuario en tiempo real en la colección 'users'
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Caso de seguridad: el documento no se ha creado aún
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = userSnapshot.data!.data() ?? {};
            final String role = userData['role'] ?? 'pending';

            // 3. ENRUTADOR DE ROLES (Role Wrapper)
            // Esto asegura que cada rol vea su contenido y no pueda acceder a otros
            switch (role) {
              case 'admin':
              case 'coordinator':
              case 'player':
                // Estos roles entran a la HomeScreen adaptativa que configuramos
                return HomeScreen(userData: userData);
              
              case 'coach':
                // Para testing, el coach va al perfil, pero se puede añadir a HomeScreen adaptativa luego
                return const ProfileScreen();

              case 'pending':
              default:
                // Usuario nuevo sin rol elegido
                return const RoleSelectionScreen();
            }
          },
        );
      },
    );
  }
}
