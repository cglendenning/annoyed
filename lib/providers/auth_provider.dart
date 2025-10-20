import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

// EmailAuthProvider is part of firebase_auth but needs explicit reference
// ignore: implementation_imports
import 'package:firebase_auth/firebase_auth.dart' show EmailAuthProvider;

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
    // Clear auth wall flag when user signs in with email
    await prefs.setBool('auth_wall_triggered', false);
  }
  
  /// Check if user has ever signed in with email
  static Future<bool> hasEverSignedInWithEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_ever_signed_in_with_email') ?? false;
  }
  
  /// Mark that user has hit the auth wall (persists across app restarts)
  static Future<void> markAuthWallTriggered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_wall_triggered', true);
  }
  
  /// Check if user has hit the auth wall
  static Future<bool> hasHitAuthWall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auth_wall_triggered') ?? false;
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
        debugPrint('[linkAnonymousToEmail] Error: No anonymous user to link');
        throw Exception('No anonymous user to link');
      }
      
      debugPrint('[linkAnonymousToEmail] Starting account linking for email: $email');
      
      // Create email/password credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Link anonymous account to email/password
      debugPrint('[linkAnonymousToEmail] Attempting to link credential...');
      final userCredential = await _user!.linkWithCredential(credential);
      _user = userCredential.user;
      
      debugPrint('[linkAnonymousToEmail] Successfully linked! New UID: ${_user?.uid}');
      
      // Store user preferences in Firestore
      if (_user != null) {
        debugPrint('[linkAnonymousToEmail] Storing user preferences in Firestore...');
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
      debugPrint('[linkAnonymousToEmail] Marking as signed in with email...');
      await _markHasSignedInWithEmail();
      
      await AnalyticsService.logEvent('account_upgraded');
      notifyListeners();
      debugPrint('[linkAnonymousToEmail] Account linking completed successfully');
    } catch (e) {
      debugPrint('[linkAnonymousToEmail] ERROR: $e');
      debugPrint('[linkAnonymousToEmail] ERROR Type: ${e.runtimeType}');
      debugPrint('[linkAnonymousToEmail] ERROR String: ${e.toString()}');
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
    
    final uid = _user!.uid;
    debugPrint('[AuthProvider] Starting account deletion for uid: $uid');
    
    // Track which deletions succeeded
    final deletionResults = <String, bool>{};
    
    // Helper to safely delete a collection
    Future<void> safeDeleteCollection(String collectionName, Future<void> Function() deleteFn) async {
      try {
        await deleteFn();
        deletionResults[collectionName] = true;
        debugPrint('[AuthProvider] ✓ Deleted $collectionName');
      } catch (e) {
        deletionResults[collectionName] = false;
        debugPrint('[AuthProvider] ✗ Failed to delete $collectionName: $e');
      }
    }
    
    // Delete all collections (continue even if some fail)
    await Future.wait([
      safeDeleteCollection('users', () async {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }),
      
      safeDeleteCollection('annoyances', () async {
        final snapshot = await FirebaseFirestore.instance.collection('annoyances')
            .where('uid', isEqualTo: uid).get();
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }),
      
      safeDeleteCollection('coaching', () async {
        final snapshot = await FirebaseFirestore.instance.collection('coaching')
            .where('uid', isEqualTo: uid).get();
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }),
      
      safeDeleteCollection('suggestions', () async {
        final snapshot = await FirebaseFirestore.instance.collection('suggestions')
            .where('uid', isEqualTo: uid).get();
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }),
      
      safeDeleteCollection('events', () async {
        final snapshot = await FirebaseFirestore.instance.collection('events')
            .where('uid', isEqualTo: uid).get();
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }),
      
      safeDeleteCollection('llm_cost', () async {
        final snapshot = await FirebaseFirestore.instance.collection('llm_cost')
            .where('uid', isEqualTo: uid).get();
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }),
    ]);
    
    debugPrint('[AuthProvider] Deletion results: $deletionResults');
    
    // Delete Firebase Auth account (this is the most important part)
    // Note: This may fail if user hasn't authenticated recently
    // Caller should handle re-authentication if needed
    try {
      await _user!.delete();
      debugPrint('[AuthProvider] ✓ Auth account deleted');
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] ✗ Failed to delete auth account: $e');
      // If auth deletion fails, throw error with the specific error
      rethrow;
    }
    
    debugPrint('[AuthProvider] Account deletion completed');
  }
  
  /// Re-authenticate user before sensitive operations like account deletion
  Future<void> reauthenticateWithPassword(String password) async {
    if (_user == null || _user!.email == null) {
      throw Exception('No authenticated user or email');
    }
    
    try {
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: password,
      );
      await _user!.reauthenticateWithCredential(credential);
      debugPrint('[AuthProvider] Re-authentication successful');
    } catch (e) {
      debugPrint('[AuthProvider] Re-authentication failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
    _user = null;
    notifyListeners();
  }
}



