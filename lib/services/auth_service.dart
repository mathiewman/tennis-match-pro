import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_notification_service.dart'; // ← AGREGADO

class AuthService {
  final FirebaseAuth      _auth         = FirebaseAuth.instance;
  final GoogleSignIn      _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db           = FirebaseFirestore.instance;

  // ── SIGN IN CON GOOGLE ───────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Forzar selector de cuenta
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      // Solo esto es crítico — si falla, retorna null con sign-out implícito
      final userCredential = await _auth.signInWithCredential(credential);

      // Firestore y FCM van en background: NO bloquean la navegación.
      // El AuthGate tiene su propio timeout de seguridad.
      _ensureUserInFirestore(userCredential.user!);
      PushNotificationService.refreshToken();

      return userCredential;
    } catch (e) {
      return null;
    }
  }

  // ── SIGN OUT COMPLETO ────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      // Eliminar el FCM token del dispositivo antes de cerrar sesión
      await PushNotificationService.removeToken();

      await _auth.signOut();
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
    } catch (_) {}
  }

  // ── ROL Y PERFIL ─────────────────────────────────────────────────────────
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }

  // ── GUARDAR NIVEL DE TENIS (llamar desde onboarding) ─────────────────────
  Future<void> saveTennisLevel(String uid, String level) async {
    await _db.collection('users').doc(uid).update({
      'tennisLevel':    level,
      'onboardingDone': true,
    });
  }

  // ── GUARDAR DATOS COMPLETOS DE ONBOARDING (nivel + categoría + club) ───────
  Future<void> saveOnboardingData(
      String uid, String level, String category, {
      String? homeClubId, String? homeClubName}) async {
    await _db.collection('users').doc(uid).update({
      'tennisLevel':    level,
      'category':       category,
      'onboardingDone': true,
      if (homeClubId != null && homeClubId.isNotEmpty)
        'homeClubId': homeClubId,
      if (homeClubName != null && homeClubName.isNotEmpty)
        'homeClubName': homeClubName,
    });
  }

  // ── CREAR / ACTUALIZAR USUARIO EN FIRESTORE ──────────────────────────────
  // Se llama sin await — corre en background.
  // Nunca debe dejar excepciones sin manejar (Dart las loguea como unhandled).
  Future<void> _ensureUserInFirestore(User user) async {
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final doc    = await docRef.get();

      if (!doc.exists) {
        // Usuario nuevo — crear perfil inicial
        await docRef.set({
          'uid':            user.uid,
          'displayName':    user.displayName ?? 'Sin Nombre',
          'email':          user.email ?? '',
          'photoUrl':       user.photoURL ?? '',
          'role':           'pending',
          'tennisLevel':    '',
          'onboardingDone': false,
          'balance_coins':  0,
          'isAvailable':    false,
          'eloRating':      1000,
          'createdAt':      DateTime.now().toIso8601String(),
        });
      } else {
        // Usuario existente — actualizar campos básicos sin tocar photoUrl
        // (el usuario gestiona su propia foto desde el perfil)
        final existing = doc.data()!;
        await docRef.update({
          'displayName':   user.displayName ?? existing['displayName'] ?? '',
          'email':         user.email       ?? existing['email']       ?? '',
          'googlePhotoUrl': user.photoURL   ?? '',
          'lastLoginAt':   DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Fallo silencioso — el AuthGate tiene timeout de seguridad para nuevos usuarios
    }
  }
}
