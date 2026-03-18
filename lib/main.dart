import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'widgets/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/global_statistics_screen.dart';
import 'screens/club_profile_screen.dart';
import 'screens/edit_club_screen.dart';
import 'screens/tournament_players_screen.dart';
import 'screens/club_explorer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('es', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tennis Match Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A34)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A3A34),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/global_statistics') {
          final clubId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => GlobalStatisticsScreen(clubId: clubId));
        }
        if (settings.name == '/club_profile') {
          final clubId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: clubId));
        }
        if (settings.name == '/edit_club') {
          final clubId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => EditClubScreen(clubId: clubId));
        }
        return null;
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/tournament_players': (context) => const TournamentPlayersScreen(),
        '/club_explorer': (context) => const ClubExplorerScreen(),
      },
      home: const AuthGate(),
    );
  }
}
