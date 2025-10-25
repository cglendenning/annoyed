import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/auth_state.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

/// Single source of truth for authentication state.
/// Derives all state from Firebase Auth + minimal persistence flags.
/// 
/// This replaces the old AuthProvider with a cleaner state machine approach.
class AuthStateManager extends ChangeNotifier {
  AuthState _currentState = AuthState.initializing;
  User? _firebaseUser;
  String? _errorMessage;
  AuthState? _previousStateBeforeError;
  StreamSubscription<User?>? _authSubscription;
  int _retryCount = 0;
  Timer? _retryTimer;

  // Constants
  static const int _maxAutoRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _operationTimeout = Duration(seconds: 30);

  // Getters
  AuthState get state => _currentState;
  User? get user => _firebaseUser;
  String? get errorMessage => _errorMessage;
  
  // Derived state from Firebase Auth (no parallel tracking)
  bool get isAnonymous => _firebaseUser?.isAnonymous ?? false;
  bool get isAuthenticated => _firebaseUser != null;
  bool get hasEmail => _firebaseUser?.email != null;
  String? get userId => _firebaseUser?.uid;
  String? get userEmail => _firebaseUser?.email;

  /// Initialize the auth state manager
  /// Sets up the Firebase Auth listener (single source of truth)
  Future<void> initialize() async {
    debugPrint('[AuthStateManager] Initializing...');
    
    // Listen to Firebase Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (error) {
        debugPrint('[AuthStateManager] Auth stream error: $error');
        _handleError(error, AuthState.anonymousActive);
      },
    );
  }

  /// Called whenever Firebase Auth state changes
  /// This is THE single source of truth
  Future<void> _onAuthStateChanged(User? user) async {
    debugPrint('[AuthStateManager] Firebase auth changed: user=${user?.uid}, isAnonymous=${user?.isAnonymous}, email=${user?.email}');
    
    _firebaseUser = user;
    
    // CRITICAL: Link RevenueCat to Firebase UID IMMEDIATELY when user authenticates
    // This must happen BEFORE any purchases so subscriptions are tied to the correct user
    if (user != null) {
      await _linkRevenueCatUser(user.uid);
    }
    
    // Sync subscription status for authenticated users (AWAIT IT - must complete before proceeding)
    if (user != null && !user.isAnonymous) {
      await _syncSubscriptionStatus(user.uid);
    }
    
    // Compute new state based on Firebase Auth + minimal flags
    final newState = await _computeState();
    
    if (newState != _currentState) {
      debugPrint('[AuthStateManager] State transition: $_currentState → $newState');
      _currentState = newState;
      notifyListeners();
    }
  }
  
  /// Public method to force subscription sync (for debug/manual trigger)
  Future<void> forceSyncSubscription() async {
    if (_firebaseUser != null && !_firebaseUser!.isAnonymous) {
      await _syncSubscriptionStatus(_firebaseUser!.uid);
    } else {
      throw Exception('No authenticated user');
    }
  }
  
  /// Link RevenueCat anonymous user to Firebase UID
  /// This MUST be called before any purchases to ensure subscriptions follow the user across devices
  Future<void> _linkRevenueCatUser(String uid) async {
    try {
      debugPrint('[AuthStateManager] Linking RevenueCat to Firebase UID: $uid');
      
      // Login transfers any purchases from anonymous user to the identified user
      final loginResult = await Purchases.logIn(uid);
      
      debugPrint('[AuthStateManager] RevenueCat login result:');
      debugPrint('[AuthStateManager]   - created: ${loginResult.created}');
      debugPrint('[AuthStateManager]   - originalAppUserId: ${loginResult.customerInfo.originalAppUserId}');
      debugPrint('[AuthStateManager]   - active subscriptions: ${loginResult.customerInfo.activeSubscriptions}');
      debugPrint('[AuthStateManager]   - entitlements: ${loginResult.customerInfo.entitlements.all.keys.toList()}');
      
      if (loginResult.created) {
        debugPrint('[AuthStateManager] ✅ New RevenueCat user created for Firebase UID');
      } else {
        debugPrint('[AuthStateManager] ✅ Logged into existing RevenueCat user');
      }
      
      // The logIn() call automatically transfers any anonymous purchases to this identified user
      // So if user subscribed while anonymous, their subscription is now linked to their Firebase account
      
    } catch (e) {
      debugPrint('[AuthStateManager] ❌ Error linking RevenueCat user: $e');
      // Don't throw - linking is important but shouldn't block auth flow
    }
  }
  
  /// Sync RevenueCat subscription status to Firestore
  /// This ensures isPro field is always up to date
  Future<void> _syncSubscriptionStatus(String uid) async {
    try {
      debugPrint('[AuthStateManager] Syncing subscription status for $uid');
      
      // Invalidate cache and sync to get latest subscription status
      await Purchases.invalidateCustomerInfoCache();
      await Purchases.syncPurchases();
      
      // Check RevenueCat subscription status
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.all['premium']?.isActive == true || 
                        customerInfo.activeSubscriptions.isNotEmpty;
      
      debugPrint('[AuthStateManager] RevenueCat premium status: $isPremium');
      debugPrint('[AuthStateManager] All entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      debugPrint('[AuthStateManager] Active subscriptions: ${customerInfo.activeSubscriptions}');
      debugPrint('[AuthStateManager] Original app user ID: ${customerInfo.originalAppUserId}');
      
      if (isPremium) {
        // Load current preferences
        final prefs = await FirebaseService.getUserPreferences(uid);
        
        // Check if we need to update (if not pro or expires within 30 days)
        final needsUpdate = !prefs.isPro || 
                           (prefs.proUntil?.isBefore(DateTime.now().add(const Duration(days: 30))) ?? true);
        
        if (needsUpdate) {
          debugPrint('[AuthStateManager] Updating pro status in Firestore');
          
          // Update with 1 year from now
          final proUntil = DateTime.now().add(const Duration(days: 365));
          final updated = prefs.copyWith(proUntil: proUntil);
          
          await FirebaseService.updateUserPreferences(updated);
          debugPrint('[AuthStateManager] ✅ Pro status synced: isPro=true, proUntil=$proUntil');
        } else {
          debugPrint('[AuthStateManager] Pro status already up to date');
        }
      }
    } catch (e) {
      debugPrint('[AuthStateManager] Error syncing subscription status: $e');
      // Don't throw - subscription sync is non-critical
    }
  }

  /// Compute the current auth state from Firebase Auth + persistence flags
  /// This is the ONLY place where state is determined
  Future<AuthState> _computeState() async {
    // Read minimal flags from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    final authWallHit = prefs.getBool('auth_wall_hit') ?? false;

    debugPrint('[AuthStateManager] Computing state:');
    debugPrint('  - firebaseUser: ${_firebaseUser?.uid}');
    debugPrint('  - isAnonymous: ${_firebaseUser?.isAnonymous}');
    debugPrint('  - hasEmail: ${_firebaseUser?.email != null}');
    debugPrint('  - onboardingCompleted: $onboardingCompleted');
    debugPrint('  - authWallHit: $authWallHit');

    // No Firebase user and no onboarding → new user flow
    if (_firebaseUser == null && !onboardingCompleted) {
      return AuthState.needsOnboarding;
    }

    // No Firebase user but onboarding completed → need to create anonymous account
    // (This shouldn't happen normally, but handles edge cases like sign out)
    if (_firebaseUser == null && onboardingCompleted) {
      return AuthState.needsOnboarding; // Will trigger anonymous sign in
    }

    // Anonymous user at auth wall → HARD gate, must upgrade
    if (_firebaseUser!.isAnonymous && authWallHit) {
      return AuthState.anonymousAtAuthWall;
    }

    // Anonymous user, normal flow
    if (_firebaseUser!.isAnonymous) {
      return AuthState.anonymousActive;
    }

    // Email user → check if email is verified
    if (_firebaseUser!.email != null) {
      // Reload user to get fresh emailVerified status
      try {
        await _firebaseUser!.reload();
        _firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (e) {
        debugPrint('[AuthStateManager] Error reloading user: $e');
      }
      
      if (!(_firebaseUser!.emailVerified)) {
        debugPrint('[AuthStateManager] Email not verified yet');
        return AuthState.authenticatedUnverified;
      }
      
      return AuthState.authenticatedActive;
    }

    // Fallback (shouldn't reach here)
    debugPrint('[AuthStateManager] WARNING: Unexpected state, defaulting to anonymousActive');
    return AuthState.anonymousActive;
  }

  /// Mark onboarding as complete and sign in anonymously
  Future<void> completeOnboarding() async {
    try {
      debugPrint('[AuthStateManager] Completing onboarding...');
      
      _currentState = AuthState.onboardingInProgress;
      notifyListeners();

      // Save onboarding completion flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      // Sign in anonymously (Firebase native)
      debugPrint('[AuthStateManager] Signing in anonymously...');
      await FirebaseAuth.instance.signInAnonymously();
      
      await AnalyticsService.logInstall();
      
      // State will update automatically via authStateChanges listener
      debugPrint('[AuthStateManager] Onboarding complete, waiting for auth state change...');
      
    } catch (e) {
      debugPrint('[AuthStateManager] Error completing onboarding: $e');
      _handleError(e, AuthState.needsOnboarding);
    }
  }

  /// Trigger the auth wall after 5th annoyance
  Future<void> triggerAuthWall() async {
    try {
      debugPrint('[AuthStateManager] Triggering auth wall...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_wall_hit', true);

      // Recompute state
      final newState = await _computeState();
      if (newState != _currentState) {
        _currentState = newState;
        notifyListeners();
      }
      
      await AnalyticsService.logEvent('auth_wall_triggered');
      
    } catch (e) {
      debugPrint('[AuthStateManager] Error triggering auth wall: $e');
      // Don't fail here - just log it
    }
  }

  /// Upgrade anonymous account to email account
  /// Uses Firebase's native linkWithCredential() - preserves UID automatically
  Future<void> upgradeToEmail({
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    if (_firebaseUser == null || !_firebaseUser!.isAnonymous) {
      throw Exception('Cannot upgrade: no anonymous user');
    }

    try {
      debugPrint('[AuthStateManager] Starting upgrade to email...');
      _currentState = AuthState.upgradingAnonymous;
      _errorMessage = null;
      _retryCount = 0;
      notifyListeners();

      // CRITICAL: Clear auth wall flag BEFORE linking credential
      // Otherwise authStateChanges will fire and read the old flag value
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_wall_hit', false);
      debugPrint('[AuthStateManager] Cleared auth_wall_hit flag before linking');

      // Create email credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Firebase native account linking - preserves UID automatically!
      debugPrint('[AuthStateManager] Linking credential...');
      final userCredential = await _firebaseUser!.linkWithCredential(credential).timeout(
        _operationTimeout,
        onTimeout: () => throw TimeoutException('Network timeout. Please check your connection.'),
      );

      // CRITICAL: Update our cached user reference immediately
      _firebaseUser = userCredential.user;
      debugPrint('[AuthStateManager] Successfully linked! UID: ${_firebaseUser?.uid}');
      debugPrint('[AuthStateManager] User isAnonymous: ${_firebaseUser?.isAnonymous}');
      debugPrint('[AuthStateManager] User email: ${_firebaseUser?.email}');

      // Send verification email
      try {
        await _firebaseUser!.sendEmailVerification();
        debugPrint('[AuthStateManager] ✉️ Verification email sent to ${_firebaseUser!.email}');
      } catch (e) {
        debugPrint('[AuthStateManager] ⚠️ Failed to send verification email: $e');
        // Don't fail the sign-up if email sending fails
      }

      // Save user metadata to Firestore
      if (_firebaseUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_firebaseUser!.uid)
            .set({
          'email': email,
          'marketingOptIn': marketingOptIn,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedTermsAt': FieldValue.serverTimestamp(),
          'gdprConsent': true,
          'upgradedFromAnonymous': true,
        });
      }

      await AnalyticsService.logEvent('account_upgraded');

      // Immediately recompute state with the updated user
      // (authStateChanges will also fire, but this eliminates any timing window)
      final newState = await _computeState();
      if (newState != _currentState) {
        _currentState = newState;
        debugPrint('[AuthStateManager] State updated immediately after upgrade: $newState');
        notifyListeners();
      }
      
      debugPrint('[AuthStateManager] Upgrade complete!');
      
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthStateManager] Firebase auth error during upgrade: ${e.code} - ${e.message}');
      
      // Handle specific Firebase errors
      String userMessage;
      if (e.code == 'email-already-in-use') {
        userMessage = 'This email is already registered. Please sign in instead or use a different email.';
      } else if (e.code == 'credential-already-in-use') {
        userMessage = 'This email is linked to another account. Please sign in or use a different email.';
      } else if (e.code == 'invalid-email') {
        userMessage = 'Invalid email address. Please check and try again.';
      } else if (e.code == 'weak-password') {
        userMessage = 'Password is too weak. Please use a stronger password.';
      } else {
        userMessage = 'Sign up failed: ${e.message ?? 'Unknown error'}';
      }
      
      _handleError(userMessage, AuthState.anonymousAtAuthWall);
      rethrow;
      
    } on TimeoutException catch (e) {
      debugPrint('[AuthStateManager] Timeout during upgrade: $e');
      _handleError('Network timeout. Please check your connection and try again.', AuthState.anonymousAtAuthWall);
      rethrow;
      
    } catch (e) {
      debugPrint('[AuthStateManager] Unexpected error during upgrade: $e');
      _handleError('Sign up failed. Please try again.', AuthState.anonymousAtAuthWall);
      rethrow;
    }
  }

  /// Sign in with existing email account
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthStateManager] Starting sign in...');
      _currentState = AuthState.signingIn;
      _errorMessage = null;
      _retryCount = 0;
      notifyListeners();

      // Firebase native sign in
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        _operationTimeout,
        onTimeout: () => throw TimeoutException('Network timeout. Please check your connection.'),
      );

      // CRITICAL: Update our cached user reference immediately
      _firebaseUser = userCredential.user;
      debugPrint('[AuthStateManager] Sign in successful! UID: ${_firebaseUser?.uid}');

      // Immediately recompute state with the signed-in user
      final newState = await _computeState();
      if (newState != _currentState) {
        _currentState = newState;
        debugPrint('[AuthStateManager] State updated immediately after sign in: $newState');
        notifyListeners();
      }
      
      debugPrint('[AuthStateManager] Sign in complete!');
      
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthStateManager] Firebase auth error during sign in: ${e.code} - ${e.message}');
      
      // For security, use generic message for sign in errors (prevent account enumeration)
      String userMessage = 'Invalid email or password. Please try again.';
      
      if (e.code == 'network-request-failed' || e.code == 'too-many-requests') {
        userMessage = 'Network error. Please check your connection and try again.';
      }
      
      _handleError(userMessage, AuthState.anonymousActive);
      rethrow;
      
    } on TimeoutException catch (e) {
      debugPrint('[AuthStateManager] Timeout during sign in: $e');
      _handleError('Network timeout. Please check your connection and try again.', AuthState.anonymousActive);
      rethrow;
      
    } catch (e) {
      debugPrint('[AuthStateManager] Unexpected error during sign in: $e');
      _handleError('Sign in failed. Please try again.', AuthState.anonymousActive);
      rethrow;
    }
  }

  /// Sign up with email (for new users, not upgrade)
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    try {
      debugPrint('[AuthStateManager] Starting sign up...');
      _currentState = AuthState.signingIn; // Reuse signing in state
      _errorMessage = null;
      _retryCount = 0;
      notifyListeners();

      // Create user with Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        _operationTimeout,
        onTimeout: () => throw TimeoutException('Network timeout. Please check your connection.'),
      );

      // CRITICAL: Update our cached user reference immediately
      _firebaseUser = userCredential.user;
      debugPrint('[AuthStateManager] User created! UID: ${_firebaseUser?.uid}');

      // Send verification email
      try {
        await _firebaseUser!.sendEmailVerification();
        debugPrint('[AuthStateManager] ✉️ Verification email sent to ${_firebaseUser!.email}');
      } catch (e) {
        debugPrint('[AuthStateManager] ⚠️ Failed to send verification email: $e');
        // Don't fail the sign-up if email sending fails
      }

      // Save user metadata to Firestore
      if (_firebaseUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_firebaseUser!.uid)
            .set({
          'email': email,
          'marketingOptIn': marketingOptIn,
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedTermsAt': FieldValue.serverTimestamp(),
          'gdprConsent': true,
        });
      }

      await AnalyticsService.logInstall();

      // Immediately recompute state with the new user
      final newState = await _computeState();
      if (newState != _currentState) {
        _currentState = newState;
        debugPrint('[AuthStateManager] State updated immediately after sign up: $newState');
        notifyListeners();
      }
      
      debugPrint('[AuthStateManager] Sign up complete!');
      
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthStateManager] Firebase auth error during sign up: ${e.code} - ${e.message}');
      
      String userMessage;
      if (e.code == 'email-already-in-use') {
        userMessage = 'This email is already registered. Please sign in instead.';
      } else if (e.code == 'invalid-email') {
        userMessage = 'Invalid email address. Please check and try again.';
      } else if (e.code == 'weak-password') {
        userMessage = 'Password is too weak. Please use a stronger password.';
      } else {
        userMessage = 'Sign up failed: ${e.message ?? 'Unknown error'}';
      }
      
      _handleError(userMessage, AuthState.anonymousActive);
      rethrow;
      
    } on TimeoutException catch (e) {
      debugPrint('[AuthStateManager] Timeout during sign up: $e');
      _handleError('Network timeout. Please check your connection and try again.', AuthState.anonymousActive);
      rethrow;
      
    } catch (e) {
      debugPrint('[AuthStateManager] Unexpected error during sign up: $e');
      _handleError('Sign up failed. Please try again.', AuthState.anonymousActive);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email).timeout(
        _operationTimeout,
        onTimeout: () => throw TimeoutException('Network timeout. Please check your connection.'),
      );
    } catch (e) {
      debugPrint('[AuthStateManager] Error sending password reset: $e');
      rethrow;
    }
  }

  /// Re-authenticate user before sensitive operations like account deletion
  Future<void> reauthenticateWithPassword(String password) async {
    if (_firebaseUser == null || _firebaseUser!.email == null) {
      throw Exception('No authenticated user or email');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: _firebaseUser!.email!,
        password: password,
      );
      await _firebaseUser!.reauthenticateWithCredential(credential);
      debugPrint('[AuthStateManager] Re-authentication successful');
    } catch (e) {
      debugPrint('[AuthStateManager] Re-authentication failed: $e');
      rethrow;
    }
  }

  /// Delete user account and all data (GDPR right to be forgotten)
  Future<void> deleteAccount() async {
    if (_firebaseUser == null) return;

    final uid = _firebaseUser!.uid;
    debugPrint('[AuthStateManager] Starting account deletion for uid: $uid');

    try {
      // Delete Firestore data (reuse existing logic from old AuthProvider)
      await _deleteUserData(uid);

      // Delete Firebase Auth account
      await _firebaseUser!.delete();
      debugPrint('[AuthStateManager] Auth account deleted');

      // Clear local flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // State will update automatically via authStateChanges listener
      
    } catch (e) {
      debugPrint('[AuthStateManager] Failed to delete account: $e');
      rethrow;
    }
  }

  /// Helper to delete all user data from Firestore
  Future<void> _deleteUserData(String uid) async {
    final firestore = FirebaseFirestore.instance;
    
    // Delete all collections (continue even if some fail)
    await Future.wait([
      _safeDeleteCollection(firestore, 'users', uid),
      _safeDeleteDocsByQuery(firestore, 'annoyances', uid),
      _safeDeleteDocsByQuery(firestore, 'coaching', uid),
      _safeDeleteDocsByQuery(firestore, 'suggestions', uid),
      _safeDeleteDocsByQuery(firestore, 'events', uid),
      _safeDeleteDocsByQuery(firestore, 'llm_cost', uid),
    ]);
  }

  Future<void> _safeDeleteCollection(FirebaseFirestore firestore, String collection, String docId) async {
    try {
      await firestore.collection(collection).doc(docId).delete();
      debugPrint('[AuthStateManager] ✓ Deleted $collection/$docId');
    } catch (e) {
      debugPrint('[AuthStateManager] ✗ Failed to delete $collection/$docId: $e');
    }
  }

  Future<void> _safeDeleteDocsByQuery(FirebaseFirestore firestore, String collection, String uid) async {
    try {
      final snapshot = await firestore.collection(collection).where('uid', isEqualTo: uid).get();
      await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      debugPrint('[AuthStateManager] ✓ Deleted ${snapshot.docs.length} docs from $collection');
    } catch (e) {
      debugPrint('[AuthStateManager] ✗ Failed to delete from $collection: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      debugPrint('[AuthStateManager] Signing out...');
      _currentState = AuthState.signingOut;
      notifyListeners();

      await FirebaseAuth.instance.signOut();

      // Clear auth wall flag on sign out
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_wall_hit', false);

      // State will update automatically via authStateChanges listener
      
    } catch (e) {
      debugPrint('[AuthStateManager] Error signing out: $e');
      _handleError('Sign out failed. Please try again.', AuthState.authenticatedActive);
    }
  }

  /// Handle errors with auto-retry logic
  void _handleError(Object error, AuthState fallbackState) {
    _errorMessage = error.toString();
    _previousStateBeforeError = fallbackState;
    _currentState = AuthState.authError;
    notifyListeners();

    // Auto-retry with exponential backoff
    if (_retryCount < _maxAutoRetries) {
      _retryCount++;
      final delay = _retryDelay * _retryCount;
      debugPrint('[AuthStateManager] Auto-retry $_retryCount/$_maxAutoRetries in ${delay.inSeconds}s...');
      
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        debugPrint('[AuthStateManager] Auto-retry attempt $_retryCount...');
        retryLastOperation();
      });
    } else {
      debugPrint('[AuthStateManager] Max retries reached. User action required.');
    }
  }

  /// Retry the last failed operation
  void retryLastOperation() {
    _retryTimer?.cancel();
    // This will be called by UI or auto-retry
    // For now, just return to previous state
    if (_previousStateBeforeError != null) {
      _currentState = _previousStateBeforeError!;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Cancel current operation and return to safe state
  void cancelOperation() {
    _retryTimer?.cancel();
    _retryCount = 0;
    if (_previousStateBeforeError != null) {
      _currentState = _previousStateBeforeError!;
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

