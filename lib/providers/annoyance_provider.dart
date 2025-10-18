import 'package:flutter/foundation.dart';
import '../models/annoyance.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/redaction_service.dart';

class AnnoyanceProvider with ChangeNotifier {
  List<Annoyance> _annoyances = [];
  bool _isLoading = false;
  String? _error;

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

  /// Load user annoyances
  Future<void> loadAnnoyances(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _annoyances = await FirebaseService.getUserAnnoyances(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading annoyances: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save a new annoyance
  Future<String?> saveAnnoyance({
    required String uid,
    required String transcript,
  }) async {
    try {
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

      // Reload annoyances
      await loadAnnoyances(uid);

      return id;
    } catch (e) {
      _error = e.toString();
      print('Error saving annoyance: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update an annoyance
  Future<void> updateAnnoyance(Annoyance annoyance, String uid) async {
    try {
      await FirebaseService.updateAnnoyance(annoyance);
      await loadAnnoyances(uid);
    } catch (e) {
      _error = e.toString();
      print('Error updating annoyance: $e');
      notifyListeners();
    }
  }

  /// Delete an annoyance
  Future<void> deleteAnnoyance(String id, String uid) async {
    try {
      await FirebaseService.deleteAnnoyance(id);
      await loadAnnoyances(uid);
    } catch (e) {
      _error = e.toString();
      print('Error deleting annoyance: $e');
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







