import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../models/annoyance.dart';
import '../models/suggestion.dart';
import '../models/user_preferences.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  // Auth methods
  static Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  static Future<UserCredential> signInWithApple() async {
    // Generate a random nonce for security
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    // Request Apple Sign In
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    // Create OAuth credential for Firebase
    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    // Sign in to Firebase with Apple credential
    return await _auth.signInWithCredential(oauthCredential);
  }

  static Future<UserCredential> signInWithGoogle() async {
    // Initialize Google Sign In
    final GoogleSignIn googleSignIn = GoogleSignIn();
    
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      // User canceled the sign-in
      throw Exception('Google Sign In was cancelled');
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with Google credential
    return await _auth.signInWithCredential(credential);
  }

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Collections
  static CollectionReference get usersCollection => _firestore.collection('users');
  static CollectionReference get annoyancesCollection =>
      _firestore.collection('annoyances');
  static CollectionReference get suggestionsCollection =>
      _firestore.collection('suggestions');
  static CollectionReference get eventsCollection => _firestore.collection('events');
  static CollectionReference get llmCostCollection =>
      _firestore.collection('llm_cost');

  // User Preferences
  static Future<UserPreferences> getUserPreferences(String uid) async {
    final doc = await usersCollection.doc(uid).get();
    return UserPreferences.fromFirestore(doc);
  }

  static Future<void> updateUserPreferences(UserPreferences prefs) async {
    await usersCollection.doc(prefs.uid).set(
          prefs.toFirestore(),
          SetOptions(merge: true),
        );
  }

  // Annoyances
  static Future<String> saveAnnoyance(Annoyance annoyance) async {
    final docRef = await annoyancesCollection.add(annoyance.toFirestore());
    return docRef.id;
  }

  static Future<Annoyance?> getAnnoyance(String id) async {
    final doc = await annoyancesCollection.doc(id).get();
    if (!doc.exists) return null;
    return Annoyance.fromFirestore(doc);
  }

  static Stream<List<Annoyance>> streamUserAnnoyances(String uid) {
    return annoyancesCollection
        .where('uid', isEqualTo: uid)
        .orderBy('ts', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Annoyance.fromFirestore(doc)).toList());
  }

  static Future<List<Annoyance>> getUserAnnoyances(String uid,
      {int? limit}) async {
    Query query = annoyancesCollection
        .where('uid', isEqualTo: uid)
        .orderBy('ts', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Annoyance.fromFirestore(doc)).toList();
  }

  static Future<void> updateAnnoyance(Annoyance annoyance) async {
    await annoyancesCollection.doc(annoyance.id).update(annoyance.toFirestore());
  }

  static Future<void> deleteAnnoyance(String id) async {
    await annoyancesCollection.doc(id).delete();
  }

  // Suggestions
  static Future<String> saveSuggestion(Suggestion suggestion) async {
    final docRef = await suggestionsCollection.add(suggestion.toFirestore());
    return docRef.id;
  }

  static Future<void> updateSuggestion(Suggestion suggestion) async {
    await suggestionsCollection.doc(suggestion.id).update(suggestion.toFirestore());
  }

  static Stream<List<Suggestion>> streamUserSuggestions(String uid) {
    return suggestionsCollection
        .where('uid', isEqualTo: uid)
        .orderBy('ts', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Suggestion.fromFirestore(doc)).toList());
  }

  static Future<List<Suggestion>> getUserSuggestions(String uid,
      {int? limit}) async {
    Query query = suggestionsCollection
        .where('uid', isEqualTo: uid)
        .orderBy('ts', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Suggestion.fromFirestore(doc)).toList();
  }

  static Future<int> getUserSuggestionCount(String uid) async {
    final snapshot =
        await suggestionsCollection.where('uid', isEqualTo: uid).count().get();
    return snapshot.count ?? 0;
  }

  // Analytics Events
  static Future<void> logEvent(String type, Map<String, dynamic>? meta) async {
    final uid = currentUserId;
    if (uid == null) return;

    await eventsCollection.add({
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
      'type': type,
      'meta': meta ?? {},
    });
  }

  // Cloud Functions
  static Future<Map<String, dynamic>> classifyAnnoyance(String text) async {
    try {
      final callable = _functions.httpsCallable('classifyAnnoyance');
      final result = await callable.call({'text': text});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling classifyAnnoyance: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> generateSuggestion({
    required String uid,
    required String category,
    required String trigger,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateSuggestion');
      final result = await callable.call({
        'uid': uid,
        'category': category,
        'trigger': trigger,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling generateSuggestion: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> generateCoaching({
    required String uid,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateCoaching');
      // Add timestamp to prevent caching
      final result = await callable.call({
        'uid': uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling generateCoaching: $e');
      rethrow;
    }
  }

  // Get user's cost usage status
  static Future<Map<String, dynamic>> getUserCostStatus({
    required String uid,
  }) async {
    try {
      final callable = _functions.httpsCallable('getUserCostStatus');
      final result = await callable.call({
        'uid': uid,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling getUserCostStatus: $e');
      rethrow;
    }
  }

  // Coaching resonance
  static Future<String> saveCoachingResonance({
    required String uid,
    required String recommendation,
    required String type,
    required String resonance, // 'hell_yes' or 'meh' or '' for not rated yet
    String? explanation,
  }) async {
    final docRef = await _firestore.collection('coaching').add({
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
      'recommendation': recommendation,
      'type': type,
      'resonance': resonance,
      'explanation': explanation ?? '',
    });
    return docRef.id;
  }
  
  // Get all coachings for a user (newest first)
  static Future<List<Map<String, dynamic>>> getAllCoachings({
    required String uid,
    int limit = 100, // Default limit to prevent excessive data transfer
  }) async {
    try {
      final snapshot = await _firestore
          .collection('coaching')
          .where('uid', isEqualTo: uid)
          .orderBy('ts', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Convert Firestore Timestamp to DateTime for easier handling in UI
        if (data['ts'] != null) {
          data['timestamp'] = (data['ts'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting coachings: $e');
      return [];
    }
  }

  // Delete all user data
  static Future<void> deleteAllUserData(String uid) async {
    // Delete annoyances
    final annoyancesSnapshot =
        await annoyancesCollection.where('uid', isEqualTo: uid).get();
    for (final doc in annoyancesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete suggestions
    final suggestionsSnapshot =
        await suggestionsCollection.where('uid', isEqualTo: uid).get();
    for (final doc in suggestionsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete coaching records
    final coachingSnapshot =
        await _firestore.collection('coaching').where('uid', isEqualTo: uid).get();
    for (final doc in coachingSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete events
    final eventsSnapshot =
        await eventsCollection.where('uid', isEqualTo: uid).get();
    for (final doc in eventsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete LLM cost records
    final llmCostSnapshot =
        await llmCostCollection.where('uid', isEqualTo: uid).get();
    for (final doc in llmCostSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete user preferences
    await usersCollection.doc(uid).delete();
  }
}







