import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'widgets/auth_gate.dart';
import 'services/push_notification_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/global_statistics_screen.dart';
import 'screens/club_profile_screen.dart';
import 'screens/club_dashboard_screen.dart';
import 'screens/edit_club_screen.dart';
import 'screens/tournament_players_screen.dart';
import 'screens/club_explorer_screen.dart';
import 'screens/player_home_screen.dart';
import 'screens/club_store_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar transparente con íconos claros
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF060F0C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('es', null);
  await PushNotificationService.initialize();
  await ThemeService.instance.load();

  runApp(const MatchPointApp());
}

class MatchPointApp extends StatefulWidget {
  const MatchPointApp({super.key});

  @override
  State<MatchPointApp> createState() => _MatchPointAppState();
}

class _MatchPointAppState extends State<MatchPointApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.mode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.mode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match Point',
      themeMode: ThemeService.instance.mode.value,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      onGenerateRoute: _onGenerateRoute,
      routes: {
        '/login':               (context) => const LoginScreen(),
        '/tournament_players':  (context) => const TournamentPlayersScreen(),
        '/club_explorer':       (context) => const ClubExplorerScreen(),
      },
      navigatorKey: navigatorKey,
      // SafeArea global: evita que el contenido quede detrás de la barra de
      // estado (arriba) en toda la app. bottom:false porque cada Scaffold
      // maneja su propio espacio inferior (teclado + barra de navegación).
      builder: (context, child) => SafeArea(
        bottom: false,
        child: child!,
      ),
      home: const AuthGate(),
    );
  }

  // ─── Tema claro ──────────────────────────────────────────────────────────────
  // Paleta: fondo arena-verdoso suave, superficies blanco roto, acento verde
  // oscuro y lima, textos oscuros con contraste alto. Coherente con el dark theme.
  ThemeData _buildLightTheme() {
    const lime        = Color(0xFFCCFF00);        // mismo acento del dark
    const deepGreen   = Color(0xFF0B2218);        // texto principal
    const brandGreen  = Color(0xFF1A3A34);        // appbar / headers
    const accentGreen = Color(0xFF2D6A4F);        // botones / iconos activos
    const scaffoldBg  = Color(0xFFEFF4F0);        // fondo general: verde muy pálido
    const surfaceBg   = Color(0xFFF8FBF8);        // cards / inputs
    const surfaceDark = Color(0xFFDFECE3);        // superficies secundarias

    final base = ThemeData.light();

    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,

      colorScheme: const ColorScheme.light(
        primary:     accentGreen,
        onPrimary:   Colors.white,
        secondary:   accentGreen,
        onSecondary: Colors.white,
        surface:     surfaceBg,
        onSurface:   deepGreen,
        error:       Color(0xFFB00020),
        onError:     Colors.white,
      ),

      textTheme: GoogleFonts.barlowCondensedTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.bebasNeue(
            fontSize: 72, letterSpacing: 4, color: deepGreen),
        displayMedium: GoogleFonts.bebasNeue(
            fontSize: 52, letterSpacing: 3, color: deepGreen),
        displaySmall: GoogleFonts.bebasNeue(
            fontSize: 36, letterSpacing: 2, color: deepGreen),
        headlineLarge: GoogleFonts.barlowCondensed(
            fontSize: 28, fontWeight: FontWeight.w900,
            letterSpacing: 1, color: deepGreen),
        headlineMedium: GoogleFonts.barlowCondensed(
            fontSize: 22, fontWeight: FontWeight.w700, color: deepGreen),
        titleLarge: GoogleFonts.barlowCondensed(
            fontSize: 18, fontWeight: FontWeight.w700,
            letterSpacing: 0.5, color: deepGreen),
        bodyLarge: GoogleFonts.barlow(
            fontSize: 16, fontWeight: FontWeight.w400, color: deepGreen),
        bodyMedium: GoogleFonts.barlow(
            fontSize: 14, color: const Color(0xFF1C3A2E)),
        bodySmall: GoogleFonts.barlow(
            fontSize: 11, color: const Color(0xFF4A6B5A)),
        labelLarge: GoogleFonts.barlowCondensed(
            fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: Colors.white),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: brandGreen,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 20, fontWeight: FontWeight.w700,
          letterSpacing: 1, color: Colors.white,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: deepGreen,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentGreen,
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB2CFC0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB2CFC0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentGreen, width: 1.8),
        ),
        labelStyle: GoogleFonts.barlowCondensed(
            color: const Color(0xFF4A6B5A), letterSpacing: 1),
        hintStyle: GoogleFonts.barlowCondensed(
            color: const Color(0xFF7A9A8A), letterSpacing: 0.5),
      ),

      cardTheme: CardThemeData(
        color: surfaceBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFCCDDD4)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceDark,
        selectedColor: lime,
        labelStyle: GoogleFonts.barlowCondensed(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: deepGreen),
        side: const BorderSide(color: Color(0xFFB2CFC0)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceBg,
        selectedItemColor: accentGreen,
        unselectedItemColor: Color(0xFF7A9A8A),
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accentGreen : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF7FBA9A)
                : const Color(0xFFCCDDD4)),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFCCDDD4),
        thickness: 1, space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: brandGreen,
        contentTextStyle: GoogleFonts.barlowCondensed(
            color: Colors.white, fontSize: 14, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.barlowCondensed(
            fontSize: 20, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: deepGreen),
        contentTextStyle: GoogleFonts.barlow(
            fontSize: 14, color: const Color(0xFF4A6B5A)),
      ),
    );
  }

  // ─── Tema oscuro (original) ───────────────────────────────────────────────
  ThemeData _buildDarkTheme() {
    const deepGreen  = Color(0xFF0B2218);
    const appGreen   = Color(0xFF1A3A34);
    const lime       = Color(0xFFD2E414);

    final base = ThemeData.dark();

    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A1F1A),

      colorScheme: const ColorScheme.dark(
        primary:          lime,
        onPrimary:        deepGreen,
        secondary:        lime,
        onSecondary:      deepGreen,
        surface:          appGreen,
        onSurface:        Colors.white,
        background:       deepGreen,
        onBackground:     Colors.white,
        error:            Color(0xFFFF6B6B),
        onError:          Colors.white,
      ),

      // Tipografía global — Barlow Condensed
      textTheme: GoogleFonts.barlowCondensedTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.bebasNeue(
            fontSize: 72, letterSpacing: 4, color: Colors.white),
        displayMedium: GoogleFonts.bebasNeue(
            fontSize: 52, letterSpacing: 3, color: Colors.white),
        displaySmall: GoogleFonts.bebasNeue(
            fontSize: 36, letterSpacing: 2, color: Colors.white),
        headlineLarge: GoogleFonts.barlowCondensed(
            fontSize: 28, fontWeight: FontWeight.w900,
            letterSpacing: 1, color: Colors.white),
        headlineMedium: GoogleFonts.barlowCondensed(
            fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: GoogleFonts.barlowCondensed(
            fontSize: 18, fontWeight: FontWeight.w700,
            letterSpacing: 0.5, color: Colors.white),
        bodyLarge: GoogleFonts.barlow(
            fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
        bodyMedium: GoogleFonts.barlow(
            fontSize: 14, color: Colors.white70),
        bodySmall: GoogleFonts.barlow(
            fontSize: 11, color: Colors.white38),
        labelLarge: GoogleFonts.barlowCondensed(
            fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: deepGreen),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Colors.white,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: deepGreen,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lime,
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lime, width: 1.5),
        ),
        labelStyle: GoogleFonts.barlowCondensed(
            color: Colors.white54, letterSpacing: 1),
        hintStyle: GoogleFonts.barlowCondensed(
            color: Colors.white24, letterSpacing: 0.5),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: const Color(0xFF1A3A34),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(0.07),
        selectedColor: lime.withOpacity(0.2),
        labelStyle: GoogleFonts.barlowCondensed(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: Colors.white),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),

      // Bottom nav bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF060F0C),
        selectedItemColor: lime,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.selected) ? lime : Colors.white38),
        trackColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.selected)
            ? lime.withOpacity(0.3)
            : Colors.white12),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A4D32),
        contentTextStyle: GoogleFonts.barlowCondensed(
            color: Colors.white, fontSize: 14, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A3A34),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.barlowCondensed(
            fontSize: 20, fontWeight: FontWeight.w700,
            letterSpacing: 1, color: Colors.white),
        contentTextStyle: GoogleFonts.barlow(
            fontSize: 14, color: Colors.white60),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/global_statistics':
        return MaterialPageRoute(
            builder: (_) => GlobalStatisticsScreen(
                clubId: settings.arguments as String));
      case '/club_profile':
        return MaterialPageRoute(
            builder: (_) => ClubProfileScreen(
                clubId: settings.arguments as String));
      case '/club_dashboard':
        return MaterialPageRoute(
            builder: (_) => ClubDashboardScreen(
                clubId: settings.arguments as String));
      case '/edit_club':
        return MaterialPageRoute(
            builder: (_) => EditClubScreen(
                clubId: settings.arguments as String));
      case '/store':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
            builder: (_) => ClubStoreScreen(
                clubId: args['clubId'], clubName: args['clubName']));
    }
    return null;
  }
}