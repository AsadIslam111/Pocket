import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _googleSignInInitialized = false;

  bool get isLoggedIn => _firebaseAuth.currentUser != null;
  String? get userName => _firebaseAuth.currentUser?.displayName;
  String? get userEmail => _firebaseAuth.currentUser?.email;
  String? get userId => _firebaseAuth.currentUser?.uid;

  /// Whether the current user signed in via Google (vs email/password).
  bool get isGoogleUser {
    final providers = _firebaseAuth.currentUser?.providerData ?? [];
    return providers.any((p) => p.providerId == 'google.com');
  }

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  /// Ensure GoogleSignIn.instance.initialize() is called exactly once.
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
  }

  /// Sign in with Google using google_sign_in v7 API.
  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // Trigger the interactive Google Sign-In flow.
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      // Get the ID token from authentication data.
      final String? idToken = account.authentication.idToken;

      // Create a Firebase credential using just the idToken.
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      notifyListeners();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return; // User cancelled — not an error.
      }
      debugPrint('Error signing in with Google: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      // Also sign out from Google if initialized.
      if (_googleSignInInitialized) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {
          // If Google sign-out fails, Firebase sign-out still succeeded.
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
