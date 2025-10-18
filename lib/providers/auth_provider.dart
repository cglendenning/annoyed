import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> signInAnonymously() async {
    try {
      final credential = await FirebaseService.signInAnonymously();
      _user = credential.user;
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      print('Error signing in: $e');
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
      print('Error signing in with Apple: $e');
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
      print('Error signing in with Google: $e');
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
      
      await AnalyticsService.logInstall();
      notifyListeners();
    } catch (e) {
      print('Error signing up: $e');
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
      
      await AnalyticsService.logEvent('account_upgraded');
      notifyListeners();
    } catch (e) {
      print('Error linking anonymous account: $e');
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
      notifyListeners();
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }
  
  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset: $e');
      rethrow;
    }
  }
  
  /// Delete user account and all data (GDPR right to be forgotten)
  Future<void> deleteAccount() async {
    if (_user == null) return;
    
    try {
      final uid = _user!.uid;
      
      // Delete all user data from Firestore collections in parallel
      await Future.wait([
        // Delete user document
        FirebaseFirestore.instance.collection('users').doc(uid).delete(),
        
        // Delete annoyances
        FirebaseFirestore.instance.collection('annoyances')
            .where('uid', isEqualTo: uid)
            .get()
            .then((snapshot) => Future.wait(
              snapshot.docs.map((doc) => doc.reference.delete())
            )),
        
        // Delete coaching records
        FirebaseFirestore.instance.collection('coaching')
            .where('uid', isEqualTo: uid)
            .get()
            .then((snapshot) => Future.wait(
              snapshot.docs.map((doc) => doc.reference.delete())
            )),
        
        // Delete suggestions
        FirebaseFirestore.instance.collection('suggestions')
            .where('uid', isEqualTo: uid)
            .get()
            .then((snapshot) => Future.wait(
              snapshot.docs.map((doc) => doc.reference.delete())
            )),
        
        // Delete events
        FirebaseFirestore.instance.collection('events')
            .where('uid', isEqualTo: uid)
            .get()
            .then((snapshot) => Future.wait(
              snapshot.docs.map((doc) => doc.reference.delete())
            )),
        
        // Delete LLM cost records (GDPR compliance)
        FirebaseFirestore.instance.collection('llm_cost')
            .where('uid', isEqualTo: uid)
            .get()
            .then((snapshot) => Future.wait(
              snapshot.docs.map((doc) => doc.reference.delete())
            )),
      ]);
      
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







