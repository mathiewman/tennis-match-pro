import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String adminEmail = 'matiasdlr9@gmail.com';

  Future<UserCredential?> signInWithGoogle() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _ensureUserInFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Error during Google sign-in: $e');
      return null;
    }
  }

  Future<void> _ensureUserInFirestore(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      String initialRole = (user.email == adminEmail) ? 'admin' : 'pending';

      final userData = {
        'uid': user.uid,
        'displayName': user.displayName ?? 'Sin Nombre',
        'email': user.email ?? '',
        'photoURL': user.photoURL,
        'role': initialRole,
        'createdAt': FieldValue.serverTimestamp(),
        'balance_coins': 0,
      };
      
      await docRef.set(userData);
    } else {
      if (user.email == adminEmail && doc.data()?['role'] != 'admin') {
        await docRef.update({'role': 'admin'});
      }
    }
  }

  // Método restaurado para la selección de rol
  Future<void> updateUserRole(String uid, String newRole) async {
    await _db.collection('users').doc(uid).update({'role': newRole});
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect().catchError((_) => null);
      await _googleSignIn.signOut().catchError((_) => null);
      await _auth.signOut();
      print("Sesión cerrada y desconectada correctamente.");
    } catch (e) {
      print('Error signing out: $e');
      await _auth.signOut();
    }
  }

  Stream<User?> get userStream => _auth.authStateChanges();
}
