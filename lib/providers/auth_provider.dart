import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;

  AuthProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }
  
  /// Mark that user has signed in with email (persists across app restarts)
  Future<void> _markHasSignedInWithEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_ever_signed_in_with_email', true);
  }
  
  /// Check if user has ever signed in with email
  static Future<bool> hasEverSignedInWithEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_ever_signed_in_with_email') ?? false;
  }

  Future<void> signInAnonymously() async {
    try {
      final credential = await FirebaseService.signInAnonymously();
      _user = credential.user;
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      final credential = await FirebaseService.signInWithApple();
      _user = credential.user;
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final credential = await FirebaseService.signInWithGoogle();
      _user = credential.user;
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    try {
      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = credential.user;
      
      // Store user preferences in Firestore (GDPR & CCPA compliant)
      if (_user != null) {
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
          'email': email,
          'marketingOptIn': marketingOptIn,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedTermsAt': FieldValue.serverTimestamp(),
          'gdprConsent': true,
        });
      }
      
      // Mark that user has signed in with email
      await _markHasSignedInWithEmail();
      
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }
  
  /// Link anonymous account to email/password (upgrade)
  /// This preserves all user data from anonymous session
  Future<void> linkAnonymousToEmail({
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    try {
      if (_user == null || !_user!.isAnonymous) {
        throw Exception('No anonymous user to link');
      }
      
      // Create email/password credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Link anonymous account to email/password
      final userCredential = await _user!.linkWithCredential(credential);
      _user = userCredential.user;
      
      // Store user preferences in Firestore
      if (_user != null) {
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
          'email': email,
          'marketingOptIn': marketingOptIn,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedTermsAt': FieldValue.serverTimestamp(),
          'gdprConsent': true,
          'upgradedFromAnonymous': true,
        });
        
        // Update all existing annoyances with the email
        // (they already have the correct uid, so no migration needed)
      }
      
      // Mark that user has signed in with email
      await _markHasSignedInWithEmail();
      
      await AnalyticsService.logEvent('account_upgraded');
      notifyListeners();
    } catch (e) {
      debugPrint('Error linking anonymous account: $e');
      rethrow;
    }
  }
  
  /// Sign in with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = credential.user;
      
      // Mark that user has signed in with email
      await _markHasSignedInWithEmail();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }
  
  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset: $e');
      rethrow;
    }
  }
  
  /// Delete user account and all data (GDPR right to be forgotten)
  Future<void> deleteAccount() async {
    if (_user == null) return;
    
    try {
      final uid = _user!.uid;
      
      // Delete all user data from Firestore using centralized service method
      await FirebaseService.deleteAllUserData(uid);
      
      // Delete Firebase Auth account
      await _user!.delete();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
    _user = null;
    notifyListeners();
  }
}



