import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORES DE MARCA — Match Point
// ─────────────────────────────────────────────────────────────────────────────
class MPColors {
  static const deepGreen  = Color(0xFF0B2218);
  static const appGreen   = Color(0xFF1A3A34);
  static const midGreen   = Color(0xFF1A4D32);
  static const lime       = Color(0xFFD2E414);
  static const limeBright = Color(0xFFECF82A);
  static const limeDark   = Color(0xFF97AD02);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isSigningIn = false;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 150), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: MPColors.deepGreen,
      body: Stack(children: [

        // ── Fondo: cancha ilustrada ──────────────────────────────────────────
        Positioned.fill(
          child: CustomPaint(painter: _CourtPainter()),
        ),

        // ── Gradiente oscuro sobre la cancha ─────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 0.60, 1.0],
                colors: [
                  MPColors.deepGreen.withOpacity(0.2),
                  MPColors.deepGreen.withOpacity(0.1),
                  MPColors.deepGreen.withOpacity(0.75),
                  MPColors.deepGreen,
                ],
              ),
            ),
          ),
        ),

        // ── Glow lime sutil en el centro-arriba ───────────────────────────────
        Positioned(
          top: size.height * 0.10,
          left: 0, right: 0,
          child: Center(
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MPColors.lime.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Contenido principal ───────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [

              SizedBox(height: size.height * 0.10),

              // ── Ícono + wordmark ─────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(children: [

                    // Ícono flotante
                    AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: child,
                      ),
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: MPColors.lime.withOpacity(0.30),
                                blurRadius: 40,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: MPColors.appGreen,
                                child: const Center(
                                  child: Text('🎾',
                                      style: TextStyle(fontSize: 40)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Wordmark
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.bebasNeue(
                          fontSize: 58,
                          letterSpacing: 4,
                          height: 0.95,
                        ),
                        children: const [
                          TextSpan(
                            text: 'MATCH\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'POINT',
                            style: TextStyle(color: MPColors.lime),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtítulo
                    Text(
                      'TENNIS MANAGEMENT PLATFORM',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.28),
                        letterSpacing: 3.5,
                      ),
                    ),
                  ]),
                ),
              ),

              const Spacer(),

              // ── Sección inferior ──────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [

                  // Tagline
                  Text(
                    'Canchas, torneos y reservas.\nTodo en un lugar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.45),
                      letterSpacing: 0.5,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Botón Google
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isSigningIn
                        ? _loadingButton()
                        : _googleButton(),
                  ),

                  const SizedBox(height: 16),

                  // Términos
                  Text(
                    'Al continuar aceptás los términos de uso.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlow(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.18),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Firma mathiewman
                  Text(
                    'by mathiewman',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlow(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.12),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _googleButton() => GestureDetector(
    onTap: _signIn,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: MPColors.lime,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MPColors.lime.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('G',
                style: GoogleFonts.barlow(
                    color: MPColors.deepGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'CONTINUAR CON GOOGLE',
          style: GoogleFonts.barlowCondensed(
            color: MPColors.deepGreen,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ]),
    ),
  );

  Widget _loadingButton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      color: MPColors.lime.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MPColors.lime.withOpacity(0.3)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(MPColors.lime),
        ),
      ),
      const SizedBox(width: 14),
      Text(
        'Iniciando sesión...',
        style: GoogleFonts.barlowCondensed(
          color: MPColors.lime,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    ]),
  );

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    final authService = AuthService();
    try {
      final userCredential = await authService.signInWithGoogle();
      if (mounted && userCredential == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al iniciar sesión. Intentá de nuevo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COURT PAINTER — cancha de tenis con colores Match Point
// ─────────────────────────────────────────────────────────────────────────────
class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Superficie
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0D2B24),
    );

    final line = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final lineAccent = Paint()
      ..color = MPColors.lime.withOpacity(0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cL = w * 0.08, cR = w * 0.92;
    final cT = h * 0.05, cB = h * 0.58;
    final cMY = (cT + cB) / 2, cMX = (cL + cR) / 2;

    // Rectángulo exterior
    canvas.drawRect(Rect.fromLTRB(cL, cT, cR, cB), line);

    // Net
    canvas.drawLine(Offset(cL, cMY), Offset(cR, cMY),
        line..strokeWidth = 2.5..color = Colors.white.withOpacity(0.10));
    line.strokeWidth = 1.5;
    line.color = Colors.white.withOpacity(0.07);

    // Línea central vertical
    canvas.drawLine(Offset(cMX, cT), Offset(cMX, cB), lineAccent);

    // Cuadros de servicio
    final si = w * 0.12;
    for (final x in [cL + si, cR - si]) {
      canvas.drawLine(Offset(x, cT), Offset(x, cB), line);
    }

    // Líneas de servicio horizontales
    final sTy = cT + (cMY - cT) * 0.45;
    final sByY = cB - (cB - cMY) * 0.45;
    canvas.drawLine(Offset(cL + si, sTy), Offset(cR - si, sTy), line);
    canvas.drawLine(Offset(cL + si, sByY), Offset(cR - si, sByY), line);

    // Postes
    final post = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(cL - 4, cMY - 8), Offset(cL - 4, cMY + 8), post);
    canvas.drawLine(Offset(cR + 4, cMY - 8), Offset(cR + 4, cMY + 8), post);

    // Pelota sutil
    canvas.drawCircle(
      Offset(cMX * 1.12, cT + (cMY - cT) * 0.55),
      9,
      Paint()
        ..color = MPColors.lime.withOpacity(0.18)
        ..style = PaintingStyle.fill,
    );
    // Glow de la pelota
    canvas.drawCircle(
      Offset(cMX * 1.12, cT + (cMY - cT) * 0.55),
      18,
      Paint()
        ..color = MPColors.lime.withOpacity(0.05)
        ..style = PaintingStyle.fill,
    );

    // Líneas decorativas inferiores
    final deco = Paint()
      ..color = MPColors.lime.withOpacity(0.025)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 10; i++) {
      canvas.drawLine(
          Offset(0, h * (0.62 + i * 0.04)),
          Offset(w, h * (0.62 + i * 0.04)),
          deco);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
