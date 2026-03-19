import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      body: Stack(children: [

        // ── Fondo: cancha ilustrada ────────────────────────────────────────
        Positioned.fill(
          child: CustomPaint(painter: _CourtPainter()),
        ),

        // ── Gradiente sobre la cancha ──────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.65, 1.0],
                colors: [
                  const Color(0xFF0A1F1A).withOpacity(0.3),
                  const Color(0xFF0A1F1A).withOpacity(0.15),
                  const Color(0xFF0A1F1A).withOpacity(0.7),
                  const Color(0xFF0A1F1A),
                ],
              ),
            ),
          ),
        ),

        // ── Contenido ────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [

              // Espacio superior — deja ver la cancha
              SizedBox(height: size.height * 0.12),

              // ── Logo / nombre ────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(children: [

                    // Pelota animada
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFCCFF00),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCCFF00).withOpacity(0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🎾',
                              style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nombre de la plataforma (genérico hasta definir marca)
                    const Text(
                      'TENNIS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 0.9,
                      ),
                    ),
                    const Text(
                      'MANAGER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFCCFF00),
                        letterSpacing: -2,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GESTIÓN DE CLUBES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.3),
                        letterSpacing: 4,
                      ),
                    ),
                  ]),
                ),
              ),

              const Spacer(),

              // ── Sección inferior ──────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [

                  // Tagline
                  const Text(
                    'Torneos, canchas y más — todo en un lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white54,
                      letterSpacing: 0.3,
                      height: 1.4,
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
                  const SizedBox(height: 20),

                  // Aviso de privacidad
                  Text(
                    'Al continuar aceptás los términos de uso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 40),
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
        color: const Color(0xFFCCFF00),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCCFF00).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Logo G de Google simplificado
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('G',
                style: TextStyle(
                    color: Color(0xFF0A1F1A),
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Continuar con Google',
          style: TextStyle(
            color: Color(0xFF0A1F1A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ]),
    ),
  );

  Widget _loadingButton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      color: const Color(0xFFCCFF00).withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: const Color(0xFFCCFF00).withOpacity(0.3)),
    ),
    child: const Row(
        mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
        ),
      ),
      SizedBox(width: 14),
      Text('Iniciando sesión...',
          style: TextStyle(
              color: Color(0xFFCCFF00),
              fontSize: 15,
              fontWeight: FontWeight.w600)),
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
// PINTOR DE CANCHA DE TENIS
// ─────────────────────────────────────────────────────────────────────────────
class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Superficie de la cancha — verde oscuro profundo
    final courtPaint = Paint()
      ..color = const Color(0xFF0D2B24)
      ..style = PaintingStyle.fill;

    // Ocupar toda la pantalla
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), courtPaint);

    // Líneas de la cancha
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final lineAccent = Paint()
      ..color = const Color(0xFFCCFF00).withOpacity(0.06)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // ── Cancha completa (perspectiva centrada) ────────────────────────────
    // Vista superior ligeramente inclinada
    final courtLeft   = w * 0.08;
    final courtRight  = w * 0.92;
    final courtTop    = h * 0.05;
    final courtBottom = h * 0.60;
    final courtMidY   = (courtTop + courtBottom) / 2;
    final courtMidX   = (courtLeft + courtRight) / 2;

    // Rectángulo exterior
    final outerRect = Rect.fromLTRB(
        courtLeft, courtTop, courtRight, courtBottom);
    canvas.drawRect(outerRect, linePaint);

    // Línea central (net)
    canvas.drawLine(
        Offset(courtLeft, courtMidY),
        Offset(courtRight, courtMidY),
        linePaint..strokeWidth = 2.5);

    linePaint.strokeWidth = 1.5;

    // Línea central vertical
    canvas.drawLine(
        Offset(courtMidX, courtTop),
        Offset(courtMidX, courtBottom),
        lineAccent);

    // Cuadros de servicio
    final serviceInset = w * 0.12;
    // Líneas de servicio arriba
    canvas.drawLine(
        Offset(courtLeft + serviceInset, courtTop),
        Offset(courtLeft + serviceInset, courtMidY),
        linePaint);
    canvas.drawLine(
        Offset(courtRight - serviceInset, courtTop),
        Offset(courtRight - serviceInset, courtMidY),
        linePaint);
    // Líneas de servicio abajo
    canvas.drawLine(
        Offset(courtLeft + serviceInset, courtMidY),
        Offset(courtLeft + serviceInset, courtBottom),
        linePaint);
    canvas.drawLine(
        Offset(courtRight - serviceInset, courtMidY),
        Offset(courtRight - serviceInset, courtBottom),
        linePaint);

    // Líneas de servicio horizontales
    final serviceTopY   = courtTop    + (courtMidY - courtTop) * 0.45;
    final serviceBottomY = courtBottom - (courtBottom - courtMidY) * 0.45;

    canvas.drawLine(
        Offset(courtLeft + serviceInset, serviceTopY),
        Offset(courtRight - serviceInset, serviceTopY),
        linePaint);
    canvas.drawLine(
        Offset(courtLeft + serviceInset, serviceBottomY),
        Offset(courtRight - serviceInset, serviceBottomY),
        linePaint);

    // ── Red ──────────────────────────────────────────────────────────────
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2.0;

    canvas.drawLine(
        Offset(courtLeft, courtMidY),
        Offset(courtRight, courtMidY),
        netPaint);

    // Postes de la red
    final postPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 3.0;
    canvas.drawLine(
        Offset(courtLeft - 4, courtMidY - 8),
        Offset(courtLeft - 4, courtMidY + 8),
        postPaint);
    canvas.drawLine(
        Offset(courtRight + 4, courtMidY - 8),
        Offset(courtRight + 4, courtMidY + 8),
        postPaint);

    // ── Pelota tenue en la cancha ─────────────────────────────────────────
    final ballPaint = Paint()
      ..color = const Color(0xFFCCFF00).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(courtMidX * 1.15, courtTop + (courtMidY - courtTop) * 0.6),
        10,
        ballPaint);

    // ── Líneas decorativas de fondo ───────────────────────────────────────
    final decorPaint = Paint()
      ..color = const Color(0xFFCCFF00).withOpacity(0.03)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final y = h * (0.65 + i * 0.05);
      canvas.drawLine(Offset(0, y), Offset(w, y), decorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
