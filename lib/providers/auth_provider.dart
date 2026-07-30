import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

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

  /// Tiered fallback for name: Display Name > Email Handle > Generic
  String get bestName => userName ?? userEmail?.split('@').first ?? 'A Pocket User';

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen((user) {
      if (user != null) {
        _setupOneSignal();
      } else {
        OneSignal.logout();
      }
      notifyListeners();
    });
  }

  /// Request notification permissions and setup OneSignal user
  Future<void> _setupOneSignal() async {
    try {
      if (userId != null) {
        OneSignal.login(userId!);
      }
      
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('Error setting up OneSignal: $e');
    }
  }

  /// Ensure GoogleSignIn.instance.initialize() is called exactly once.
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: '962449291333-j04ru6ckjsmos1jag3p1863ehvskeco8.apps.googleusercontent.com',
      );
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

      if (idToken == null) {
        throw Exception(
          'Failed to get ID token from Google Sign-In. '
          'Please ensure the app is configured correctly.',
        );
      }

      // Create a Firebase credential using the idToken.
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      notifyListeners();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('Google Sign-In canceled: $e');
        return; // User cancelled — not an error.
      }
      debugPrint('GoogleSignInException: code=${e.code}, message=$e');
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
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  String? _deletionVerificationCode;
  DateTime? _codeExpiry;

  /// Generate and send a 6-digit security code for account deletion.
  Future<String> sendDeletionVerificationCode() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    // Generate random 6-digit verification code
    final code = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
    _deletionVerificationCode = code;
    _codeExpiry = DateTime.now().add(const Duration(minutes: 10));

    // Save verification code record to Firestore user doc
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deletionCode': code,
        'deletionCodeExpiry': _codeExpiry!.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error storing deletion code: $e');
    }

    notifyListeners();
    return code;
  }

  /// Permanently delete account and all user data after verifying 6-digit code.
  Future<void> deleteAccount(String inputCode) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    if (_deletionVerificationCode == null ||
        _codeExpiry == null ||
        DateTime.now().isAfter(_codeExpiry!)) {
      throw Exception('Verification code has expired. Please request a new code.');
    }

    if (inputCode.trim() != _deletionVerificationCode) {
      throw Exception('Invalid verification code. Please check the code and try again.');
    }

    final uid = user.uid;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Delete user transactions subcollection
      final transactions = await firestore.collection('users').doc(uid).collection('transactions').get();
      for (final doc in transactions.docs) {
        await doc.reference.delete();
      }

      // 2. Delete user budgets subcollection
      final budgets = await firestore.collection('users').doc(uid).collection('budgets').get();
      for (final doc in budgets.docs) {
        await doc.reference.delete();
      }

      // 3. Delete user debts subcollection
      final debts = await firestore.collection('users').doc(uid).collection('debts').get();
      for (final doc in debts.docs) {
        await doc.reference.delete();
      }

      // 4. Delete user document
      await firestore.collection('users').doc(uid).delete();

      // 5. Delete Firebase Auth user
      await user.delete();

      // Reset code state
      _deletionVerificationCode = null;
      _codeExpiry = null;

      // Sign out fully
      await signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Re-authentication required. Please sign out and sign in again to delete your account.');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      rethrow;
    }
  }
}
