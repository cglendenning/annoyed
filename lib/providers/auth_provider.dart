import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;

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

  Future<void> signOut() async {
    await FirebaseService.signOut();
    _user = null;
    notifyListeners();
  }
}







