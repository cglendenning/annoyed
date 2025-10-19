import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/annoyance.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/redaction_service.dart';
import '../utils/constants.dart';

class AnnoyanceProvider with ChangeNotifier {
  List<Annoyance> _annoyances = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Annoyance>>? _subscription;

  List<Annoyance> get annoyances => _annoyances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get todayCount {
    final today = DateTime.now();
    return _annoyances.where((a) {
      return a.timestamp.year == today.year &&
          a.timestamp.month == today.month &&
          a.timestamp.day == today.day;
    }).length;
  }

  List<Annoyance> get todayAnnoyances {
    final today = DateTime.now();
    return _annoyances.where((a) {
      return a.timestamp.year == today.year &&
          a.timestamp.month == today.month &&
          a.timestamp.day == today.day;
    }).toList();
  }

  /// Start listening to user annoyances in real-time
  void startListening(String uid) {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // Cancel any existing subscription
    _subscription?.cancel();
    
    // Subscribe to real-time updates
    _subscription = FirebaseService.streamUserAnnoyances(uid).listen(
      (annoyances) {
        _annoyances = annoyances;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        debugPrint('Error streaming annoyances: $error');
        notifyListeners();
      },
    );
  }
  
  /// Stop listening to annoyances
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _annoyances = [];
    _isLoading = false;
    _error = null;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Save a new annoyance
  Future<String?> saveAnnoyance({
    required String uid,
    required String transcript,
  }) async {
    try {
      // Validate length
      if (transcript.length > AppConstants.maxAnnoyanceLength) {
        throw Exception('Annoyance is too long. Maximum length is ${AppConstants.maxAnnoyanceLength} characters.');
      }
      
      // Redact PII before sending to server
      final redactedTranscript = RedactionService.redact(transcript);

      // Classify the annoyance via Cloud Function
      final classification =
          await FirebaseService.classifyAnnoyance(redactedTranscript);

      final annoyance = Annoyance(
        id: '', // Will be set by Firestore
        uid: uid,
        timestamp: DateTime.now(),
        transcript: redactedTranscript,
        category: classification['category'] ?? 'Environment',
        trigger: classification['trigger'] ?? 'unknown',
        safe: classification['safe'] ?? true,
      );

      final id = await FirebaseService.saveAnnoyance(annoyance);

      // Log analytics
      await AnalyticsService.logAnnoyanceSaved(annoyance.category);

      // Stream will automatically update the list
      return id;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error saving annoyance: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update an annoyance
  Future<void> updateAnnoyance(Annoyance annoyance) async {
    try {
      await FirebaseService.updateAnnoyance(annoyance);
      // Stream will automatically update the list
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating annoyance: $e');
      notifyListeners();
    }
  }

  /// Delete an annoyance
  Future<void> deleteAnnoyance(String id) async {
    try {
      await FirebaseService.deleteAnnoyance(id);
      // Stream will automatically update the list
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting annoyance: $e');
      notifyListeners();
    }
  }

  /// Get category distribution
  Map<String, int> getCategoryDistribution() {
    final distribution = <String, int>{};
    for (final annoyance in _annoyances) {
      distribution[annoyance.category] =
          (distribution[annoyance.category] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get top category
  String? getTopCategory() {
    if (_annoyances.isEmpty) return null;
    final distribution = getCategoryDistribution();
    return distribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get pattern report after 3+ entries
  Map<String, dynamic>? getPatternReport() {
    if (_annoyances.length < 3) return null;

    final distribution = getCategoryDistribution();
    final topCategory = getTopCategory();
    final total = _annoyances.length;

    if (topCategory == null) return null;

    final percentage =
        ((distribution[topCategory]! / total) * 100).toStringAsFixed(0);

    return {
      'top_category': topCategory,
      'percentage': percentage,
      'total': total,
      'distribution': distribution,
    };
  }
}







